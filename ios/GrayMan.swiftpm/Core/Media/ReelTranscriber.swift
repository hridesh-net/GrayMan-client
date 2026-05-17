@preconcurrency import AVFoundation
import Foundation
@preconcurrency import Speech

// MARK: - Reel Transcriber
//
// Runs SFSpeechRecognizer alongside camera capture so the 30s reel arrives
// at the backend with a client-side transcript hint. The backend reel agent
// still runs its own Gemini STT (higher quality for Hinglish code-switching)
// — this client transcript is the resilience layer for when Gemini STT
// degrades or the audio is otherwise hard for the server to parse.
//
// Wiring: the transcriber attaches an `AVCaptureAudioDataOutput` to the
// existing capture session that's already wired to the front camera +
// mic, so audio frames go to BOTH the AVCaptureMovieFileOutput (recorded
// to disk) AND the SFSpeechAudioBufferRecognitionRequest in parallel.
// No second audio session, no double mic capture.

@MainActor
@Observable
final class ReelTranscriber {

    /// Partial-or-final hypothesis. Updated live during recording.
    private(set) var transcript: String = ""

    /// True between `start(...)` and `stop()`.
    private(set) var isRunning: Bool = false

    private weak var attachedSession: AVCaptureSession?
    private let audioOutput = AVCaptureAudioDataOutput()
    private let bufferDelegate = SampleBufferBridge()
    private let outputQueue = DispatchQueue(label: "ReelTranscriber.audio")

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // MARK: Authorization

    /// Request mic + speech recognition authorization. Mic is granted via
    /// the camera/recording flow already; this only deals with speech.
    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
    }

    // MARK: Start / stop

    /// Attach to ``session`` and begin transcribing. ``lang`` controls the
    /// recognizer locale (hi-IN / en-IN). If permission isn't granted or
    /// the locale isn't supported, this becomes a no-op — the reel still
    /// records and uploads, just with an empty transcript.
    func start(session: AVCaptureSession, lang: AppLanguage) async {
        guard !isRunning else { return }
        let status = await Self.requestAuthorization()
        guard status == .authorized else { return }

        let locale = Locale(identifier: lang.sttLocale)
        guard let rec = SFSpeechRecognizer(locale: locale), rec.isAvailable else { return }
        self.recognizer = rec

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        // On-device when the locale supports it — keeps the user's voice
        // off Apple's servers and works offline. Falls back to networked
        // recognition automatically when on-device is unavailable.
        if rec.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        self.request = req

        // Wire the audio output → request bridge.
        bufferDelegate.onSample = { [weak req] sample in
            req?.appendAudioSampleBuffer(sample)
        }
        audioOutput.setSampleBufferDelegate(bufferDelegate, queue: outputQueue)

        // Attach to session inside begin/commit so the running session
        // can pick up the new output without restarting capture.
        session.beginConfiguration()
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
        }
        session.commitConfiguration()
        attachedSession = session

        // Kick off the recognition task. Updates `transcript` on every
        // partial hypothesis; the final result lands when we end-audio.
        self.task = rec.recognitionTask(with: req) { [weak self] result, _ in
            guard let self else { return }
            if let result {
                let best = result.bestTranscription.formattedString
                Task { @MainActor in self.transcript = best }
            }
        }

        isRunning = true
    }

    /// Stop transcribing and return the final transcript. Tears down the
    /// audio output and recognition request. Returns empty string if
    /// nothing was captured.
    @discardableResult
    func stop() async -> String {
        guard isRunning else { return transcript }
        isRunning = false

        // Detach the audio output first so no further samples arrive.
        if let session = attachedSession {
            session.beginConfiguration()
            session.removeOutput(audioOutput)
            session.commitConfiguration()
        }
        attachedSession = nil
        bufferDelegate.onSample = nil

        // Signal end-of-audio so the recognizer flushes its final result.
        request?.endAudio()

        // Give the recognizer a moment to emit its final transcription.
        // SFSpeechRecognitionTask doesn't expose an async "finished" signal;
        // 600ms is empirically enough for partial → final transitions.
        try? await Task.sleep(for: .milliseconds(600))

        task?.cancel()
        task = nil
        request = nil
        recognizer = nil
        return transcript
    }
}

// MARK: - Sample buffer bridge

/// AVCaptureAudioDataOutputSampleBufferDelegate is non-isolated; we keep
/// the bridge as a tiny final class so we can stash the closure without
/// pulling the transcriber into the data callback's thread.
private final class SampleBufferBridge: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    var onSample: (@Sendable (CMSampleBuffer) -> Void)?

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        onSample?(sampleBuffer)
    }
}

// MARK: - AppLanguage → STT locale

extension AppLanguage {
    /// Best SFSpeechRecognizer locale per language. We prefer the Indian
    /// English / Hindi locales because they ship better acoustic models
    /// for accented speech than the en-US / hi-IN defaults.
    var sttLocale: String {
        switch self {
        case .hindi:   return "hi-IN"
        case .marathi: return "mr-IN"
        case .telugu:  return "te-IN"
        case .tamil:   return "ta-IN"
        case .kannada: return "kn-IN"
        case .english: return "en-IN"
        }
    }
}
