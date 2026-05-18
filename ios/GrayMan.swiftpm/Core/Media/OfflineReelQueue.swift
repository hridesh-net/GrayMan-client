import AVFoundation
import Foundation
import Network

// MARK: - Offline reel upload queue
//
// Owns the entire post-record reel pipeline: compression, upload, and
// retry. The recording flow (RecordReelView.submitReel) hands the raw
// .mov off to `enqueueRawRecording(...)` and immediately navigates the
// user to the Profile screen — neither compression (5-15s for HEVC on
// a 30s reel) nor upload (much longer on Tier-3 networks) is allowed
// to block the user flow.
//
// Pipeline:
//   1. Move the raw recording out of `tmp/` (which iOS may purge under
//      memory pressure) into Application Support so it survives a
//      relaunch.
//   2. Persist the queue index as JSON next to the files.
//   3. Subscribe to `NWPathMonitor` and flush whenever connectivity
//      returns.
//   4. For each entry: compress (if needed) → upload → finalize.
//
// Surface: `OfflineReelQueue.shared` is observed by SwiftUI views.
// Home renders a "X reels waiting to upload" banner; Profile renders a
// finer-grained "Compressing… / Uploading…" status while the active
// entry is being processed.

@Observable @MainActor
final class OfflineReelQueue {

    static let shared = OfflineReelQueue()

    /// Total entries still in the queue (compressing, uploading or
    /// waiting). Drives the Home/Profile banner badges.
    private(set) var pendingCount: Int = 0
    /// True while the queue is actively working on an entry.
    private(set) var isFlushing: Bool = false
    /// Most-recent error surfaced from a flush attempt.
    private(set) var lastError: String?
    /// One-line description of what the active entry is doing right
    /// now — "Compressing reel…", "Uploading reel…", or nil when idle.
    /// Used by ProfileView's progress banner.
    private(set) var statusMessage: String?

    private struct Entry: Codable, Identifiable {
        var id: String
        var fileURL: URL          // absolute path under Application Support
        var contentType: String
        var transcript: String?
        var createdAt: Date
        var attemptCount: Int
        /// True for raw recordings that still need HEVC compression
        /// before upload. False for entries enqueued already-compressed
        /// via the legacy `enqueue(fileURL:contentType:transcript:)` path.
        var needsCompression: Bool

        enum CodingKeys: String, CodingKey {
            case id, fileURL, contentType, transcript, createdAt
            case attemptCount, needsCompression
        }

        init(
            id: String, fileURL: URL, contentType: String, transcript: String?,
            createdAt: Date, attemptCount: Int, needsCompression: Bool,
        ) {
            self.id = id
            self.fileURL = fileURL
            self.contentType = contentType
            self.transcript = transcript
            self.createdAt = createdAt
            self.attemptCount = attemptCount
            self.needsCompression = needsCompression
        }

        /// Custom decoder so old queue.json files (written before
        /// needsCompression existed) still decode — missing field
        /// defaults to false (= "already compressed, just upload").
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(String.self, forKey: .id)
            self.fileURL = try c.decode(URL.self, forKey: .fileURL)
            self.contentType = try c.decode(String.self, forKey: .contentType)
            self.transcript = try c.decodeIfPresent(String.self, forKey: .transcript)
            self.createdAt = try c.decode(Date.self, forKey: .createdAt)
            self.attemptCount = try c.decode(Int.self, forKey: .attemptCount)
            self.needsCompression = try c.decodeIfPresent(
                Bool.self, forKey: .needsCompression,
            ) ?? false
        }
    }

    private var entries: [Entry] = []
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "OfflineReelQueue.monitor")
    private var didStartMonitor = false
    private let fileManager = FileManager.default

    private init() {
        loadFromDisk()
        pendingCount = entries.count
        startMonitor()
    }

    // MARK: - Public surface

    /// Stash a freshly-recorded raw .mov for background compression
    /// + upload. Returns synchronously after a fast file move — the
    /// caller can navigate the user away from the recording screen
    /// instantly. Compression and upload happen in the background;
    /// failures stay queued and retry on the next connectivity event.
    func enqueueRawRecording(fileURL src: URL, transcript: String?) {
        guard let stashed = try? moveOrCopyIntoStash(src) else { return }
        appendEntry(Entry(
            id: UUID().uuidString,
            fileURL: stashed,
            contentType: "video/mp4",
            transcript: transcript,
            createdAt: Date(),
            attemptCount: 0,
            needsCompression: true,
        ))
    }

    /// Stash an already-compressed reel for upload retry. Kept for
    /// callers that want to bypass the compression step (e.g. a
    /// foreground re-attempt with a file we previously compressed).
    func enqueue(fileURL src: URL, contentType: String, transcript: String?) {
        guard let stashed = try? copyIntoStash(src) else { return }
        appendEntry(Entry(
            id: UUID().uuidString,
            fileURL: stashed,
            contentType: contentType,
            transcript: transcript,
            createdAt: Date(),
            attemptCount: 0,
            needsCompression: false,
        ))
    }

    private func appendEntry(_ entry: Entry) {
        entries.append(entry)
        saveToDisk()
        pendingCount = entries.count
        // Kick a flush right away — most enqueues happen with the
        // network present (user just hit Submit). NWPathMonitor covers
        // the "queued offline, online later" case separately.
        Task { await flush() }
    }

    /// Best-effort flush. Walks the queue serially:
    ///   - Compress if needed (one-shot, errors drop the entry).
    ///   - Upload (errors stay queued, retried via NWPathMonitor).
    func flush() async {
        guard !isFlushing, !entries.isEmpty else { return }
        isFlushing = true
        defer {
            isFlushing = false
            statusMessage = nil
        }
        lastError = nil

        let snapshotIDs = entries.map(\.id)
        for id in snapshotIDs {
            guard let idx = entries.firstIndex(where: { $0.id == id }) else { continue }
            var entry = entries[idx]
            entry.attemptCount += 1
            entries[idx] = entry
            saveToDisk()

            // 1. Compress if the entry came in raw.
            if entry.needsCompression {
                statusMessage = "Compressing reel…"
                do {
                    let compressed = try await ReelCompressor.shared.compress(source: entry.fileURL)
                    // Replace the raw file with the compressed one
                    // (both stay inside Application Support).
                    try? fileManager.removeItem(at: entry.fileURL)
                    let stashed = try moveOrCopyIntoStash(compressed.url)
                    entry.fileURL = stashed
                    entry.needsCompression = false
                    if let i = entries.firstIndex(where: { $0.id == entry.id }) {
                        entries[i] = entry
                        saveToDisk()
                    }
                } catch {
                    // Compression failure is a permanent error (bad
                    // codec config, corrupted source) — drop the entry
                    // so we don't loop on it forever.
                    lastError = (error as? LocalizedError)?.errorDescription
                        ?? error.localizedDescription
                    entries.removeAll { $0.id == entry.id }
                    try? fileManager.removeItem(at: entry.fileURL)
                    saveToDisk()
                    pendingCount = entries.count
                    continue
                }
            }

            // 2. Upload.
            statusMessage = "Uploading reel…"
            do {
                _ = try await ReelUploader.shared.upload(
                    fileURL: entry.fileURL,
                    contentType: entry.contentType,
                    transcript: entry.transcript,
                )
                entries.removeAll { $0.id == entry.id }
                try? fileManager.removeItem(at: entry.fileURL)
                saveToDisk()
                pendingCount = entries.count
            } catch {
                // Network failure — leave queued and bail out so we
                // don't burn the user's data churning the same dead
                // connection. NWPathMonitor will re-trigger flush on
                // the next satisfied path.
                lastError = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                return
            }
        }
    }

    /// Drop a queued entry without sending it.
    func remove(entryID: String) {
        guard let idx = entries.firstIndex(where: { $0.id == entryID }) else { return }
        try? fileManager.removeItem(at: entries[idx].fileURL)
        entries.remove(at: idx)
        saveToDisk()
        pendingCount = entries.count
    }

    // MARK: - Persistence

    private var supportDir: URL {
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil, create: true,
        )) ?? fileManager.temporaryDirectory
        let dir = base.appendingPathComponent("OfflineReels", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var indexURL: URL { supportDir.appendingPathComponent("queue.json") }

    private func copyIntoStash(_ src: URL) throws -> URL {
        let ext = src.pathExtension.isEmpty ? "mp4" : src.pathExtension
        let dst = supportDir.appendingPathComponent("\(UUID().uuidString).\(ext)")
        if fileManager.fileExists(atPath: dst.path) {
            try fileManager.removeItem(at: dst)
        }
        try fileManager.copyItem(at: src, to: dst)
        return dst
    }

    /// Try `moveItem` first (near-instant on the same volume); fall
    /// back to copy + remove if the source and destination span
    /// different mount points.
    private func moveOrCopyIntoStash(_ src: URL) throws -> URL {
        let ext = src.pathExtension.isEmpty ? "mov" : src.pathExtension
        let dst = supportDir.appendingPathComponent("\(UUID().uuidString).\(ext)")
        if fileManager.fileExists(atPath: dst.path) {
            try fileManager.removeItem(at: dst)
        }
        do {
            try fileManager.moveItem(at: src, to: dst)
        } catch {
            try fileManager.copyItem(at: src, to: dst)
            try? fileManager.removeItem(at: src)
        }
        return dst
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([Entry].self, from: data) else { return }
        // Drop entries whose backing file got purged (e.g. user cleared
        // app storage) — they're unrecoverable.
        entries = decoded.filter { fileManager.fileExists(atPath: $0.fileURL.path) }
    }

    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(entries) {
            try? data.write(to: indexURL, options: [.atomic])
        }
    }

    // MARK: - Network monitor

    private func startMonitor() {
        guard !didStartMonitor else { return }
        didStartMonitor = true
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            if path.status == .satisfied {
                Task { @MainActor in await self.flush() }
            }
        }
        monitor.start(queue: monitorQueue)
    }
}
