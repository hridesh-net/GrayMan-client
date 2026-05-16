import SwiftUI
import UIKit
import AVFoundation

// MARK: - Errors

enum RecordingError: LocalizedError, Equatable {
    case permissionDenied
    case configurationFailed(reason: String)
    case startFailed(underlying: String)
    case stopFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:               return "Camera and microphone access are required to record your reel."
        case .configurationFailed(let why):   return "Couldn't set up the camera: \(why)"
        case .startFailed(let why):           return "Couldn't start recording: \(why)"
        case .stopFailed(let why):            return "Recording finished with an error: \(why)"
        }
    }
}

enum RecordingPermission: Equatable { case unknown, granted, denied }

// MARK: - Service protocol — depended on by the ViewModel

@MainActor
protocol RecordingService: AnyObject {
    var permission: RecordingPermission { get }
    var session: AVCaptureSession { get }

    func requestPermissions() async -> RecordingPermission
    func startSession() async
    func stopSession() async
    func startRecording() async throws
    func stopRecording() async throws -> URL
}

// MARK: - Real implementation

@MainActor
final class AVRecordingService: NSObject, RecordingService {
    let session = AVCaptureSession()
    private let output = AVCaptureMovieFileOutput()
    private var configured = false

    private(set) var permission: RecordingPermission = .unknown

    // Bridges the off-main delegate callback back to async/await callers.
    private var stopContinuation: CheckedContinuation<URL, Error>?

    func requestPermissions() async -> RecordingPermission {
        async let cam = AVCaptureDevice.requestAccess(for: .video)
        async let mic = AVCaptureDevice.requestAccess(for: .audio)
        let (camOK, micOK) = await (cam, mic)
        let granted = camOK && micOK
        guard granted else {
            permission = .denied
            return .denied
        }
        do {
            try configureIfNeeded()
            permission = .granted
        } catch {
            permission = .denied
        }
        return permission
    }

    private func configureIfNeeded() throws {
        guard !configured else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high

        guard let camDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw RecordingError.configurationFailed(reason: "no front camera available")
        }
        let camInput: AVCaptureDeviceInput
        do {
            camInput = try AVCaptureDeviceInput(device: camDevice)
        } catch {
            throw RecordingError.configurationFailed(reason: error.localizedDescription)
        }
        guard session.canAddInput(camInput) else {
            throw RecordingError.configurationFailed(reason: "couldn't attach camera input")
        }
        session.addInput(camInput)

        if let micDevice = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: micDevice),
           session.canAddInput(micInput) {
            session.addInput(micInput)
        }

        guard session.canAddOutput(output) else {
            throw RecordingError.configurationFailed(reason: "couldn't attach movie output")
        }
        session.addOutput(output)
        configured = true
    }

    func startSession() async {
        guard permission == .granted, !session.isRunning else { return }
        // Apple requires AVCaptureSession start/stop off the main thread.
        await Task.detached(priority: .userInitiated) { [session] in
            session.startRunning()
        }.value
    }

    func stopSession() async {
        guard session.isRunning else { return }
        await Task.detached(priority: .userInitiated) { [session] in
            session.stopRunning()
        }.value
    }

    func startRecording() async throws {
        guard permission == .granted else { throw RecordingError.permissionDenied }
        guard !output.isRecording else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("grayman-reel-\(UUID().uuidString).mov")
        output.startRecording(to: url, recordingDelegate: self)
    }

    func stopRecording() async throws -> URL {
        guard output.isRecording else {
            throw RecordingError.stopFailed(underlying: "not currently recording")
        }
        // Reject if a previous stop is still pending — prevents double-resume.
        if stopContinuation != nil {
            throw RecordingError.stopFailed(underlying: "another stop is already in progress")
        }
        return try await withCheckedThrowingContinuation { cont in
            stopContinuation = cont
            output.stopRecording()
        }
    }
}

extension AVRecordingService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection],
                                error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let cont = self.stopContinuation
            self.stopContinuation = nil
            if let error {
                cont?.resume(throwing: RecordingError.stopFailed(underlying: error.localizedDescription))
            } else {
                cont?.resume(returning: outputFileURL)
            }
        }
    }
}

// MARK: - Mock — for previews, simulator, and tests

@MainActor
final class MockRecordingService: RecordingService {
    let session = AVCaptureSession()
    var permission: RecordingPermission = .granted

    func requestPermissions() async -> RecordingPermission { permission }
    func startSession() async {}
    func stopSession() async {}
    func startRecording() async throws {}
    func stopRecording() async throws -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mock-reel.mov")
    }
}

// MARK: - SwiftUI preview wrapper for AVCaptureVideoPreviewLayer

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - ViewModel

@Observable @MainActor
final class RecordReelViewModel {
    enum Phase: Equatable { case idle, recording, done, failed(String) }

    private(set) var phase: Phase = .idle
    private(set) var permission: RecordingPermission = .unknown
    private(set) var elapsed: Int = 0
    private(set) var recordedURL: URL?

    let maxSeconds: Int
    let service: RecordingService

    private var timerTask: Task<Void, Never>?

    init(service: RecordingService, maxSeconds: Int = 30) {
        self.service = service
        self.maxSeconds = maxSeconds
    }

    var remaining: Int { max(0, maxSeconds - elapsed) }
    var progress: Double { Double(elapsed) / Double(maxSeconds) }

    func onAppear() async {
        permission = await service.requestPermissions()
        await service.startSession()
    }

    func onDisappear() async {
        timerTask?.cancel()
        timerTask = nil
        await service.stopSession()
    }

    func startRecording() async {
        guard phase == .idle else { return }
        do {
            try await service.startRecording()
            elapsed = 0
            phase = .recording
            startTimer()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func stopRecording() async {
        timerTask?.cancel()
        timerTask = nil
        guard phase == .recording else { return }
        do {
            recordedURL = try await service.stopRecording()
            phase = .done
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func reset() {
        timerTask?.cancel()
        timerTask = nil
        elapsed = 0
        recordedURL = nil
        phase = .idle
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                guard self.phase == .recording else { return }
                self.elapsed += 1
                if self.elapsed >= self.maxSeconds {
                    await self.stopRecording()
                    return
                }
            }
        }
    }
}
