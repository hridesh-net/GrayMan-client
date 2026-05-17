import Foundation

// MARK: - Multipart S3 uploader
//
// Production upload path. Replaces the single-shot `URLSession.upload(for:from:)`
// flow with:
//
//   1. POST /reels/upload/init  →  uploadID + N presigned PUT URLs
//   2. PUT each 5 MB part body in parallel (max 3 concurrent), retrying
//      individual parts on transient errors.
//   3. POST /reels/upload/complete with the (part_number, etag) list.
//      On any unrecoverable error: POST /reels/upload/abort.
//
// Why this matters for Tier-3 networks: a dropped TCP connection on the
// raw single-shot upload restarts the whole thing. With multipart, the
// retry is one chunk. 30s of 540p HEVC ≈ 3 MB → one chunk; 720p HEVC
// ≈ 5–6 MB → 1–2 chunks. Either way the maximum re-send is bounded.
//
// We deliberately stream parts from disk (Data(contentsOf:options:.mappedIfSafe))
// so the full file never lives in memory.

enum ReelUploadError: LocalizedError {
    case noResponse
    case partFailed(part: Int, status: Int, body: String)
    case missingETag(part: Int)
    case allRetriesExhausted(part: Int, underlying: String)

    var errorDescription: String? {
        switch self {
        case .noResponse:
            return "No response from S3 during upload."
        case .partFailed(let p, let s, let b):
            return "Part \(p) failed (HTTP \(s)): \(b)"
        case .missingETag(let p):
            return "Part \(p) succeeded but S3 didn't return an ETag header."
        case .allRetriesExhausted(let p, let u):
            return "Part \(p) failed after retries: \(u)"
        }
    }
}

@MainActor
final class ReelUploader {
    static let shared = ReelUploader()

    private let chunkSize: Int = 5 * 1024 * 1024   // 5 MB — S3's minimum
    private let maxParallelParts: Int = 3
    private let perPartAttempts: Int = 4

    /// Progress: 0.0…1.0. Called repeatedly on the main actor.
    typealias ProgressHandler = @MainActor (Double) -> Void

    /// Upload ``fileURL`` via multipart and return the backend's final
    /// AnalysisStatus (which kicks off transcoding + reel agent).
    ///
    /// ``transcript`` is an optional on-device SFSpeechRecognizer hypothesis
    /// captured while the reel was recording. The backend uses it as a hint
    /// for its own Gemini-based STT.
    ///
    /// On any error mid-upload, the abort endpoint is called best-effort
    /// so we don't leave orphaned parts in S3.
    func upload(
        fileURL: URL,
        contentType: String = "video/mp4",
        transcript: String? = nil,
        onProgress: ProgressHandler? = nil
    ) async throws -> AnalysisStatusDTO {
        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let totalSize = (attrs[.size] as? Int) ?? 0
        let partCount = max(1, Int((Double(totalSize) / Double(chunkSize)).rounded(.up)))

        let svc = WorkerService.shared
        let initResp = try await svc.initMultipartUpload(partCount: partCount, contentType: contentType)

        var completed = Array<CompletedPartDTO?>(repeating: nil, count: partCount)
        let bytesPerPart = Array(0..<partCount).map { idx -> Int in
            let start = idx * chunkSize
            return min(chunkSize, totalSize - start)
        }

        // Track bytes-uploaded across parts so progress is monotonic across
        // parallel completions. Actor used for cheap concurrent mutation.
        let progress = UploadProgress(totalBytes: totalSize)

        do {
            try await withThrowingTaskGroup(of: (Int, CompletedPartDTO).self) { group in
                var nextPartIndex = 0
                let initURLs = initResp.partURLs

                // Seed the group with up to maxParallelParts tasks.
                while nextPartIndex < min(maxParallelParts, partCount) {
                    let partIndex = nextPartIndex
                    let partInfo = initURLs[partIndex]
                    let bytes = bytesPerPart[partIndex]
                    group.addTask { [self] in
                        let etag = try await uploadOnePart(
                            fileURL: fileURL,
                            offset: partIndex * chunkSize,
                            length: bytes,
                            url: partInfo.url,
                            contentType: contentType,
                            partNumber: partInfo.partNumber,
                            progress: progress,
                            onProgress: onProgress
                        )
                        return (partIndex, CompletedPartDTO(
                            partNumber: partInfo.partNumber, etag: etag
                        ))
                    }
                    nextPartIndex += 1
                }

                // As each finishes, seed the next.
                while let result = try await group.next() {
                    let (idx, dto) = result
                    completed[idx] = dto
                    if nextPartIndex < partCount {
                        let partIndex = nextPartIndex
                        let partInfo = initURLs[partIndex]
                        let bytes = bytesPerPart[partIndex]
                        group.addTask { [self] in
                            let etag = try await uploadOnePart(
                                fileURL: fileURL,
                                offset: partIndex * chunkSize,
                                length: bytes,
                                url: partInfo.url,
                                contentType: contentType,
                                partNumber: partInfo.partNumber,
                                progress: progress,
                                onProgress: onProgress
                            )
                            return (partIndex, CompletedPartDTO(
                                partNumber: partInfo.partNumber, etag: etag
                            ))
                        }
                        nextPartIndex += 1
                    }
                }
            }
        } catch {
            // Best-effort abort so we don't pay for orphaned parts.
            try? await svc.abortMultipartUpload(key: initResp.key, uploadID: initResp.uploadID)
            throw error
        }

        let allParts = completed.compactMap { $0 }
        guard allParts.count == partCount else {
            try? await svc.abortMultipartUpload(key: initResp.key, uploadID: initResp.uploadID)
            throw ReelUploadError.noResponse
        }

        return try await svc.completeMultipartUpload(
            key: initResp.key,
            uploadID: initResp.uploadID,
            parts: allParts,
            transcript: transcript
        )
    }

    // MARK: - Per-part PUT with retry

    private func uploadOnePart(
        fileURL: URL,
        offset: Int,
        length: Int,
        url urlString: String,
        contentType: String,
        partNumber: Int,
        progress: UploadProgress,
        onProgress: ProgressHandler?
    ) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw ReelUploadError.partFailed(part: partNumber, status: 0, body: "bad presigned URL")
        }
        let data = try mappedSlice(fileURL: fileURL, offset: offset, length: length)

        var lastError: String = ""
        for attempt in 1...perPartAttempts {
            do {
                let etag = try await putOnce(
                    url: url, data: data, contentType: contentType, partNumber: partNumber
                )
                await progress.add(length)
                if let onProgress {
                    let v = await progress.fraction()
                    await MainActor.run { onProgress(v) }
                }
                return etag
            } catch let e as ReelUploadError {
                lastError = e.localizedDescription
                // 4xx (except 408) shouldn't retry — bad request won't fix itself.
                if case .partFailed(_, let status, _) = e, (400..<500).contains(status), status != 408 {
                    throw e
                }
                if attempt < perPartAttempts {
                    let backoffNs = UInt64(pow(2.0, Double(attempt))) * 250_000_000
                    try? await Task.sleep(nanoseconds: backoffNs)
                }
            } catch {
                lastError = error.localizedDescription
                if attempt < perPartAttempts {
                    let backoffNs = UInt64(pow(2.0, Double(attempt))) * 250_000_000
                    try? await Task.sleep(nanoseconds: backoffNs)
                }
            }
        }
        throw ReelUploadError.allRetriesExhausted(part: partNumber, underlying: lastError)
    }

    private func putOnce(
        url: URL, data: Data, contentType: String, partNumber: Int
    ) async throws -> String {
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        let (_, response) = try await URLSession.shared.upload(for: req, from: data)
        guard let http = response as? HTTPURLResponse else {
            throw ReelUploadError.noResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ReelUploadError.partFailed(
                part: partNumber,
                status: http.statusCode,
                body: HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            )
        }
        // S3 returns the part ETag in the `ETag` response header. AWS quotes
        // it; the CompleteMultipartUpload call must receive the quoted form
        // exactly. We pass the raw header value through unchanged.
        guard let etag = http.value(forHTTPHeaderField: "ETag") else {
            throw ReelUploadError.missingETag(part: partNumber)
        }
        return etag
    }

    /// Read a slice of the file using memory-mapping so even very large
    /// reels don't blow up our heap. The slice is created with
    /// ``Data(contentsOf:options:)`` then sub-ranged.
    private func mappedSlice(fileURL: URL, offset: Int, length: Int) throws -> Data {
        let fh = try FileHandle(forReadingFrom: fileURL)
        defer { try? fh.close() }
        try fh.seek(toOffset: UInt64(offset))
        let buf = try fh.read(upToCount: length) ?? Data()
        return buf
    }
}

// MARK: - Progress aggregator

private actor UploadProgress {
    let totalBytes: Int
    var uploaded: Int = 0

    init(totalBytes: Int) {
        self.totalBytes = totalBytes
    }

    func add(_ n: Int) {
        uploaded += n
    }

    func fraction() -> Double {
        guard totalBytes > 0 else { return 1.0 }
        return min(1.0, Double(uploaded) / Double(totalBytes))
    }
}
