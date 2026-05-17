@preconcurrency import AVFoundation
import Foundation

// MARK: - Gemini Live Voice Guide
//
// One-shot text-to-speech via Gemini Live. The backend mints a short-lived
// ephemeral token (`/voice-guide/token`); we open a WebSocket scoped to
// audio-out-only, send the script as a text turn, and stream the 24kHz PCM
// response into an `AVAudioEngine`-driven player.
//
// Why a fresh WS per `speak()`: each onboarding screen calls `speak()`
// once with a short script, and Gemini emits `turn_complete` quickly. A
// per-call WS keeps state simple and lets us fail fast back to the
// AVSpeechSynthesizer fallback without leaving sockets dangling.
//
// Fallback: on ANY error (no network, expired token, WS handshake fail,
// audio session denied, etc.) the call throws and `VoiceGuide` re-tries
// via `AVSpeechSynthesizer` so the user always hears guidance.

@MainActor
@Observable
final class GeminiLiveVoiceGuide {
    static let shared = GeminiLiveVoiceGuide()

    /// True while a Gemini-driven utterance is in flight.
    private(set) var isSpeaking: Bool = false

    private var cachedToken: VoiceGuideTokenResponse?
    private var tokenExpiry: Date?
    private var cachedTokenLang: String?

    /// (lang, sourceText) -> translated text. Avoids re-translating the
    /// same English script every time the user returns to a screen.
    private var translationCache: [TranslationCacheKey: String] = [:]

    private var currentSpeakTask: Task<Void, Error>?
    private var currentPlayer: VoiceGuidePlayer?

    private init() {}

    private struct TranslationCacheKey: Hashable {
        let lang: String
        let text: String
    }

    /// Languages whose voice guide must be pre-translated server-side
    /// because the iOS modifier only ships English fallback scripts and
    /// the native-audio Live model refuses to translate on its own.
    private static let needsTranslation: Set<String> = ["mr", "te", "ta", "kn"]

    // MARK: Public API

    /// Speak `text` aloud in `lang` via Gemini Live. Throws if Gemini is
    /// unavailable (no network, no key, WS error). Caller should catch and
    /// fall back to a local synthesizer.
    func speak(_ text: String, lang: AppLanguage) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await stop()

        let task = Task<Void, Error> { [weak self] in
            try await self?._runSpeak(text: trimmed, lang: lang)
        }
        currentSpeakTask = task
        do {
            try await task.value
        } catch {
            if Task.isCancelled || (error as? CancellationError) != nil {
                return
            }
            throw error
        }
    }

    /// Stop any in-flight utterance. Safe to call multiple times.
    func stop() async {
        currentSpeakTask?.cancel()
        currentSpeakTask = nil
        let player = currentPlayer
        currentPlayer = nil
        await player?.stop()
        isSpeaking = false
    }

    // MARK: Speak implementation

    private func _runSpeak(text: String, lang: AppLanguage) async throws {
        // For regional languages, pre-translate the English script — the
        // native-audio Live model otherwise speaks the input English with
        // a regional accent instead of the target language.
        let spokenText = try await preparedText(for: text, lang: lang)

        let token = try await fetchToken(lang: lang)
        let session = try VoiceGuideSession(token: token)
        defer { session.cancel() }

        let player = VoiceGuidePlayer()
        try await player.start()
        currentPlayer = player
        isSpeaking = true
        defer {
            isSpeaking = false
            currentPlayer = nil
        }

        try await session.sendSetup()
        try await session.sendUserText(spokenText)

        // Drain server frames until turn_complete (or cancellation).
        try await session.consume { event in
            switch event {
            case .audio(let pcm24k):
                await player.enqueue(pcm24k)
            case .turnComplete:
                // No-op — we exit the loop when consume() returns.
                break
            }
        }

        // Let any buffered audio drain before reporting completion so the
        // next screen's autoPlay doesn't clip the tail.
        await player.waitUntilDrained()
        await player.stop()
    }

    /// Return the actual text we'll send into Live for `lang`. For en/hi/
    /// hi-en this is the original input; for mr/te/ta/kn we hit the
    /// backend to translate first and cache the result.
    private func preparedText(for text: String, lang: AppLanguage) async throws -> String {
        let code = lang.geminiLangCode
        guard Self.needsTranslation.contains(code) else { return text }

        let key = TranslationCacheKey(lang: code, text: text)
        if let hit = translationCache[key] { return hit }

        let response = try await WorkerService.shared.voiceGuideTranslate(text: text, lang: lang)
        let translated = response.translated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translated.isEmpty else { return text }
        translationCache[key] = translated
        return translated
    }

    private func fetchToken(lang: AppLanguage) async throws -> VoiceGuideTokenResponse {
        let langCode = lang.geminiLangCode
        if let cached = cachedToken,
           let expiry = tokenExpiry,
           expiry > Date().addingTimeInterval(60),
           cachedTokenLang == langCode {
            return cached
        }
        let fresh = try await WorkerService.shared.voiceGuideToken(lang: lang)
        cachedToken = fresh
        cachedTokenLang = langCode
        // Server hands out 30-min tokens; cache for 25 min to keep margin.
        tokenExpiry = Date().addingTimeInterval(25 * 60)
        return fresh
    }
}

// MARK: - AppLanguage → Gemini language code

extension AppLanguage {
    /// Code accepted by the backend `/voice-guide/token` endpoint and
    /// passed through to the Live system instruction.
    var geminiLangCode: String {
        switch self {
        case .english: return "en"
        case .hindi:   return "hi"
        case .marathi: return "mr"
        case .telugu:  return "te"
        case .tamil:   return "ta"
        case .kannada: return "kn"
        }
    }
}

// MARK: - WebSocket session

private final class VoiceGuideSession: @unchecked Sendable {

    enum Event {
        case audio(Data)        // 24kHz mono int16 PCM
        case turnComplete
    }

    enum SessionError: LocalizedError {
        case badURL
        case wsClosed(String)
        case timeout

        var errorDescription: String? {
            switch self {
            case .badURL:               return "Bad Gemini Live URL"
            case .wsClosed(let why):    return "Gemini Live WS closed: \(why)"
            case .timeout:              return "Gemini Live timed out"
            }
        }
    }

    private let wsTask: URLSessionWebSocketTask
    private let model: String

    init(token: VoiceGuideTokenResponse) throws {
        guard var components = URLComponents(string: token.wsURL) else {
            throw SessionError.badURL
        }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "access_token", value: token.ephemeralToken))
        components.queryItems = items
        guard let url = components.url else { throw SessionError.badURL }

        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        wsTask = URLSession.shared.webSocketTask(with: req)
        wsTask.resume()
        self.model = token.model
    }

    func cancel() {
        wsTask.cancel(with: .goingAway, reason: nil)
    }

    func sendSetup() async throws {
        try await sendJSON(["setup": ["model": "models/\(model)"]])
    }

    func sendUserText(_ text: String) async throws {
        // Per the Gemini Live spec, mid-/post-setup text input goes via
        // `realtime_input` (the wire form of `send_realtime_input(text=…)`).
        // `client_content` is reserved for seeding initial history with
        // history_config.initial_history_in_client_content, which we don't
        // use here — each voice-guide WS is a fresh one-shot TTS session.
        let frame: [String: Any] = [
            "realtime_input": [
                "text": text,
            ],
        ]
        try await sendJSON(frame)
    }

    /// Drain frames from the server until turn_complete. The `onEvent`
    /// closure is called for each audio chunk; the loop exits on
    /// `turn_complete` or cancellation. Throws on WS error.
    func consume(onEvent: @MainActor (Event) async -> Void) async throws {
        while !Task.isCancelled {
            let msg: URLSessionWebSocketTask.Message
            do {
                msg = try await wsTask.receive()
            } catch {
                throw SessionError.wsClosed(error.localizedDescription)
            }
            let raw: String
            switch msg {
            case .string(let s): raw = s
            case .data(let d):   raw = String(data: d, encoding: .utf8) ?? ""
            @unknown default:    continue
            }
            guard let data = raw.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            // Tolerate both camel and snake casing from the server SDK.
            let serverContent = obj["serverContent"] as? [String: Any]
                ?? obj["server_content"] as? [String: Any]
            guard let sc = serverContent else { continue }

            let modelTurn = sc["modelTurn"] as? [String: Any]
                ?? sc["model_turn"] as? [String: Any]
            if let parts = modelTurn?["parts"] as? [[String: Any]] {
                for part in parts {
                    if let inline = part["inlineData"] as? [String: Any]
                        ?? part["inline_data"] as? [String: Any],
                       let b64 = inline["data"] as? String,
                       let pcm = Data(base64Encoded: b64) {
                        await onEvent(.audio(pcm))
                    }
                }
            }
            let done = (sc["turnComplete"] as? Bool) ?? (sc["turn_complete"] as? Bool) ?? false
            if done {
                await onEvent(.turnComplete)
                return
            }
        }
    }

    private func sendJSON(_ obj: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: obj, options: [])
        let text = String(data: data, encoding: .utf8) ?? ""
        do {
            try await wsTask.send(.string(text))
        } catch {
            throw SessionError.wsClosed(error.localizedDescription)
        }
    }
}

// MARK: - Audio player (24kHz mono int16 PCM → speaker)

private actor VoiceGuidePlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var pendingBuffers: Int = 0
    private let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24_000,
        channels: 1,
        interleaved: true
    )!

    func start() async throws {
        try configureSession()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: playbackFormat)
        try engine.start()
        // Don't call player.play() yet — the first enqueue() will start
        // playback once we actually have audio. Calling play() on an empty
        // queue makes the mixer render zero-byte cycles and the audio
        // subsystem spams `mBuffers[0].mDataByteSize (0)` warnings.
    }

    func stop() async {
        player.stop()
        engine.stop()
    }

    func enqueue(_ data: Data) async {
        let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Int16>.size)
        guard frameCount > 0,
              let buf = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: frameCount),
              let dst = buf.int16ChannelData?[0] else { return }
        buf.frameLength = frameCount
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            memcpy(dst, base, data.count)
        }
        pendingBuffers += 1
        let onDone: @Sendable () -> Void = { [weak self] in
            guard let self else { return }
            Task { await self.decrementPending() }
        }
        player.scheduleBuffer(buf, completionHandler: onDone)
        if !player.isPlaying { player.play() }
    }

    private func decrementPending() {
        if pendingBuffers > 0 { pendingBuffers -= 1 }
    }

    /// Block until all queued buffers have actually played out, or a
    /// safety timeout fires so we never hang the UI.
    func waitUntilDrained() async {
        let deadline = Date().addingTimeInterval(30)
        while pendingBuffers > 0 && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        // Use .playback so we work even when the phone is on silent
        // (matches the existing AVSpeechSynthesizer fallback behaviour
        // — field users keep their phones on silent on site).
        try session.setCategory(.playback, mode: .spokenAudio,
                                options: [.duckOthers])
        try session.setActive(true, options: [])
    }
}
