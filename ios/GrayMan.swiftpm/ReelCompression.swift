@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import Network
import VideoToolbox

// MARK: - Reel compression
//
// Production prep step before upload. Takes whatever the camera produced
// (AVCaptureMovieFileOutput at sessionPreset=.high → ~40 Mbps H.264) and
// re-encodes it as HEVC at a network-appropriate resolution / bitrate
// before we send a single byte to S3. A 30s reel goes from ~150 MB raw
// to ~3-6 MB.
//
// We adapt the rung to the current network:
//   - Wi-Fi or unconstrained cellular → 720p HEVC @ 1.2 Mbps  (≈4.5 MB / 30s)
//   - Constrained / metered cellular  → 540p HEVC @ 0.7 Mbps  (≈2.6 MB / 30s)
//
// The implementation uses ``AVAssetWriter`` directly rather than
// ``AVAssetExportSession`` because Apple's HEVC export presets only ship
// at 1080p and 4K — no canned preset gives us 540p HEVC at a specific
// target bitrate. AVAssetWriter is also the only way to set
// ``AVVideoAverageBitRateKey`` explicitly, which is what we actually want
// to control on a phone network.

enum ReelCompressionError: LocalizedError {
    case sourceUnreadable
    case writerSetupFailed(String)
    case writeFailed(String)
    case noVideoTrack

    var errorDescription: String? {
        switch self {
        case .sourceUnreadable:           return "Couldn't read the recorded reel."
        case .writerSetupFailed(let why): return "Couldn't prepare HEVC encoder: \(why)"
        case .writeFailed(let why):       return "Couldn't write the compressed reel: \(why)"
        case .noVideoTrack:               return "The recording has no video track."
        }
    }
}

struct CompressedReel: Sendable {
    let url: URL
    let sizeBytes: Int
    let codec: String          // "hevc"
    let width: Int
    let height: Int
    let bitrateKbps: Int
}

@MainActor
final class ReelCompressor {
    static let shared = ReelCompressor()

    /// Compress ``source`` to a temp .mp4. Output lives next to the source.
    func compress(source: URL) async throws -> CompressedReel {
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw ReelCompressionError.sourceUnreadable
        }

        let asset = AVURLAsset(url: source)
        let rung = await pickRung()
        let outputURL = source
            .deletingPathExtension()
            .appendingPathExtension("compressed.mp4")
        try? FileManager.default.removeItem(at: outputURL)

        try await encodeHEVC(asset: asset, output: outputURL, rung: rung)

        let size = (try? FileManager.default
            .attributesOfItem(atPath: outputURL.path)[.size] as? Int) ?? 0
        return CompressedReel(
            url: outputURL,
            sizeBytes: size,
            codec: "hevc",
            width: rung.width,
            height: rung.height,
            bitrateKbps: rung.videoKbps
        )
    }

    // MARK: - Rung selection

    private struct Rung: Sendable {
        let width: Int
        let height: Int
        let videoKbps: Int
        let audioKbps: Int
    }

    private func pickRung() async -> Rung {
        let path = await NetworkProbe.snapshot()
        let onWifi = path?.isWifi == true
        let constrained = path?.isConstrained == true
        if onWifi || !constrained {
            return Rung(width: 720, height: 1280, videoKbps: 1200, audioKbps: 96)
        }
        return Rung(width: 540, height: 960, videoKbps: 700, audioKbps: 64)
    }

    // MARK: - AVAssetWriter pipeline

    private func encodeHEVC(asset: AVURLAsset, output: URL, rung: Rung) async throws {
        // Load track + transform (orientation) up front so the writer can
        // declare the right output dimensions and avoid a separate
        // re-encode for rotation.
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw ReelCompressionError.noVideoTrack
        }
        let transform = try await videoTrack.load(.preferredTransform)

        // The phone records portrait → preferredTransform encodes the
        // 90° rotation. We swap output W/H so HEVC encodes the portrait
        // frame directly instead of letterboxing.
        let isPortrait = (transform.b == 1 && transform.c == -1)
                      || (transform.b == -1 && transform.c == 1)
        let outW = isPortrait ? rung.width : rung.height
        let outH = isPortrait ? rung.height : rung.width

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
        } catch {
            throw ReelCompressionError.writerSetupFailed(error.localizedDescription)
        }
        writer.shouldOptimizeForNetworkUse = true   // moov atom at the front

        // --- Video ---
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: outW,
            AVVideoHeightKey: outH,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey:           rung.videoKbps * 1_000,
                AVVideoMaxKeyFrameIntervalKey:      60,       // 1 keyframe/2s @ 30fps
                AVVideoProfileLevelKey:             kVTProfileLevel_HEVC_Main_AutoLevel as String,
                AVVideoAllowFrameReorderingKey:     true,
                AVVideoExpectedSourceFrameRateKey:  30,
            ],
        ]
        guard writer.canApply(outputSettings: videoSettings, forMediaType: .video) else {
            throw ReelCompressionError.writerSetupFailed("HEVC settings rejected by writer")
        }
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        if writer.canAdd(videoInput) { writer.add(videoInput) }

        // --- Audio ---
        var audioInput: AVAssetWriterInput?
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        if let audioTrack = audioTracks.first {
            let audioSettings: [String: Any] = [
                AVFormatIDKey:         kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey:       44_100,
                AVEncoderBitRateKey:   rung.audioKbps * 1_000,
            ]
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            input.expectsMediaDataInRealTime = false
            if writer.canAdd(input) {
                writer.add(input)
                audioInput = input
            }
            _ = audioTrack
        }

        // --- Reader ---
        let reader = try AVAssetReader(asset: asset)
        let videoReaderSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
        ]
        let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoReaderSettings)
        videoOutput.alwaysCopiesSampleData = false
        if reader.canAdd(videoOutput) { reader.add(videoOutput) }

        var audioOutput: AVAssetReaderTrackOutput?
        if audioInput != nil, let audioTrack = audioTracks.first {
            let out = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
                AVFormatIDKey:         kAudioFormatLinearPCM,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey:       44_100,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey:  false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ])
            out.alwaysCopiesSampleData = false
            if reader.canAdd(out) { reader.add(out); audioOutput = out }
        }

        guard reader.startReading() else {
            throw ReelCompressionError.writerSetupFailed(
                reader.error?.localizedDescription ?? "reader.startReading failed"
            )
        }
        guard writer.startWriting() else {
            throw ReelCompressionError.writerSetupFailed(
                writer.error?.localizedDescription ?? "writer.startWriting failed"
            )
        }
        writer.startSession(atSourceTime: .zero)

        // Pipe video samples on a serial queue. AVAssetWriterInput is not
        // Sendable on iOS 26 strict concurrency, so this whole block runs
        // on a non-main, non-async context — we just wait on a checked
        // continuation for the final state.
        try await pump(
            reader: reader, writer: writer,
            videoInput: videoInput, videoOutput: videoOutput,
            audioInput: audioInput, audioOutput: audioOutput
        )
    }

    private func pump(
        reader: AVAssetReader,
        writer: AVAssetWriter,
        videoInput: AVAssetWriterInput,
        videoOutput: AVAssetReaderTrackOutput,
        audioInput: AVAssetWriterInput?,
        audioOutput: AVAssetReaderTrackOutput?
    ) async throws {
        let videoQueue = DispatchQueue(label: "ReelCompressor.video")
        let audioQueue = DispatchQueue(label: "ReelCompressor.audio")

        async let videoDone: Void = withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            videoInput.requestMediaDataWhenReady(on: videoQueue) {
                while videoInput.isReadyForMoreMediaData {
                    if let sample = videoOutput.copyNextSampleBuffer() {
                        if !videoInput.append(sample) {
                            videoInput.markAsFinished()
                            cont.resume()
                            return
                        }
                    } else {
                        videoInput.markAsFinished()
                        cont.resume()
                        return
                    }
                }
            }
        }

        async let audioDone: Void = withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            guard let audioInput, let audioOutput else { cont.resume(); return }
            audioInput.requestMediaDataWhenReady(on: audioQueue) {
                while audioInput.isReadyForMoreMediaData {
                    if let sample = audioOutput.copyNextSampleBuffer() {
                        if !audioInput.append(sample) {
                            audioInput.markAsFinished()
                            cont.resume()
                            return
                        }
                    } else {
                        audioInput.markAsFinished()
                        cont.resume()
                        return
                    }
                }
            }
        }

        _ = await (videoDone, audioDone)
        await writer.finishWriting()

        if writer.status == .failed {
            throw ReelCompressionError.writeFailed(
                writer.error?.localizedDescription ?? "writer status failed"
            )
        }
        if reader.status == .failed {
            throw ReelCompressionError.writeFailed(
                reader.error?.localizedDescription ?? "reader status failed"
            )
        }
    }
}

// MARK: - Network probe

/// Tiny snapshot wrapper around NWPathMonitor. The path-update handler
/// fires from a background queue; we serialise access through a class with
/// a lock so the strict-concurrency checker is happy.
private enum NetworkProbe {
    struct Snapshot: Sendable {
        let isWifi: Bool
        let isConstrained: Bool
    }

    static func snapshot() async -> Snapshot? {
        await withCheckedContinuation { (cont: CheckedContinuation<Snapshot?, Never>) in
            let box = ResultBox()
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "ReelCompressor.NetworkProbe")
            monitor.pathUpdateHandler = { path in
                let snap = Snapshot(
                    isWifi: path.usesInterfaceType(.wifi),
                    isConstrained: path.isConstrained || path.isExpensive
                )
                if box.fire(snap) {
                    monitor.cancel()
                    cont.resume(returning: snap)
                }
            }
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + .milliseconds(250)) {
                if box.fire(nil) {
                    monitor.cancel()
                    cont.resume(returning: nil)
                }
            }
        }
    }

    /// Tiny lock-protected gate so only the first of {handler, timeout}
    /// fires the continuation.
    private final class ResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var resolved = false
        func fire(_: Snapshot?) -> Bool {
            lock.lock(); defer { lock.unlock() }
            if resolved { return false }
            resolved = true
            return true
        }
    }
}
