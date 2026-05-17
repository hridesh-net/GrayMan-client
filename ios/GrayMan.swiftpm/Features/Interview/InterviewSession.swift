@preconcurrency import AVFoundation
import Foundation

// MARK: - Backend-driven interview session
//
// Replaces the previous client-direct-to-Gemini-Live flow. The iOS app no
// longer holds an ephemeral Gemini token; instead it opens a WebSocket to
// our FastAPI backend (`/api/v1/interview/ws`) and the backend proxies to
// Gemini Live, intercepts tool calls server-side, and persists the final
// scores before sending them back to the client.
//
// Wire format (JSON text frames):
//
//   client -> server:
//     {"type":"audio","data":"<base64 16kHz mono int16 PCM>"}
//     {"type":"end"}                                     // optional graceful end
//
//   server -> client:
//     {"type":"ready"}                                   // setup complete
//     {"type":"audio","data":"<base64 24kHz mono int16 PCM>"}
//     {"type":"text","text":"…"}                         // optional partial
//     {"type":"scores","confidence":78,"clarity":80,"trade_competence":74,"summary":"…"}
//     {"type":"done"}                                    // closing on success
//     {"type":"error","message":"…"}

@Observable @MainActor
final class InterviewSession {

    enum State: Equatable {
        case idle, connecting, listening, speaking, ended, failed(String)
    }

    private(set) var state: State = .idle
    private(set) var lastTextTurn: String = ""

    var onScores: ((InterviewScores) -> Void)?
    var onError: ((String) -> Void)?

    private let wsTask: URLSessionWebSocketTask
    private let audio = InterviewAudioPipeline()

    private var readerTask: Task<Void, Never>?

    init(trade: String?, lang: String, token: String) throws {
        // Build wss://<host>/api/v1/interview/ws?token=…&trade=…&lang=…
        // by mutating the project's APIConfig.baseURL so the WS endpoint
        // tracks whatever host the rest of the app talks to.
        var components = URLComponents(
            url: APIConfig.baseURL, resolvingAgainstBaseURL: false
        )
        guard var c = components else {
            throw NSError(domain: "InterviewSession", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Bad API base URL"])
        }
        c.scheme = (c.scheme == "https") ? "wss" : "ws"
        c.path = (c.path as NSString).appendingPathComponent("interview/ws")
        var items: [URLQueryItem] = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "lang",  value: lang),
        ]
        if let trade { items.append(URLQueryItem(name: "trade", value: trade)) }
        c.queryItems = items
        guard let url = c.url else {
            throw NSError(domain: "InterviewSession", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Bad WS URL"])
        }
        components = c
        var req = URLRequest(url: url)
        req.timeoutInterval = 60
        wsTask = URLSession.shared.webSocketTask(with: req)
    }

    // MARK: Lifecycle

    func start() async {
        state = .connecting
        wsTask.resume()
        readerTask = Task { [weak self] in await self?.readLoop() }
        do {
            try await audio.start { [weak self] data in
                guard let self else { return }
                Task { @MainActor in await self.sendAudioChunk(data) }
            }
            state = .listening
        } catch {
            state = .failed(error.localizedDescription)
            onError?(error.localizedDescription)
        }
    }

    func stop() async {
        readerTask?.cancel()
        readerTask = nil
        await audio.stop()
        // Best-effort hangup notice so the server can close cleanly.
        try? await sendJSON(["type": "end"])
        wsTask.cancel(with: .goingAway, reason: nil)
        if case .ended = state { return }
        state = .ended
    }

    // MARK: Sending

    private func sendAudioChunk(_ pcm16k: Data) async {
        guard state == .listening || state == .speaking else { return }
        try? await sendJSON([
            "type": "audio",
            "data": pcm16k.base64EncodedString(),
        ])
    }

    private func sendJSON(_ obj: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: obj, options: [])
        let text = String(data: data, encoding: .utf8) ?? ""
        try await wsTask.send(.string(text))
    }

    // MARK: Reading

    private func readLoop() async {
        while !Task.isCancelled {
            do {
                let msg = try await wsTask.receive()
                switch msg {
                case .string(let s):
                    handleFrame(s)
                case .data(let d):
                    if let s = String(data: d, encoding: .utf8) { handleFrame(s) }
                @unknown default: break
                }
            } catch {
                let msg = error.localizedDescription
                if msg.contains("cancelled") { return }
                await MainActor.run {
                    self.state = .failed(msg)
                    self.onError?(msg)
                }
                return
            }
        }
    }

    private func handleFrame(_ raw: String) {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        let type = obj["type"] as? String ?? ""
        switch type {
        case "ready":
            // Backend confirmed Gemini setup; we're already in .listening
            // because audio capture started in start(). Nothing to do.
            break
        case "audio":
            if let b64 = obj["data"] as? String,
               let pcm = Data(base64Encoded: b64) {
                Task { await audio.enqueueServerAudio(pcm) }
                if state == .listening { state = .speaking }
            }
        case "text":
            if let text = obj["text"] as? String { lastTextTurn = text }
        case "scores":
            let scores = InterviewScores(
                confidence:       (obj["confidence"]       as? Int) ?? 0,
                clarity:          (obj["clarity"]          as? Int) ?? 0,
                tradeCompetence:  (obj["trade_competence"] as? Int) ?? 0,
                summary:          (obj["summary"]          as? String) ?? ""
            )
            onScores?(scores)
        case "done":
            state = .ended
        case "error":
            let msg = (obj["message"] as? String) ?? "Interview failed"
            state = .failed(msg)
            onError?(msg)
        default:
            // Server may add new frame types over time. Ignore unknowns.
            break
        }
    }
}

// MARK: - Audio pipeline (16kHz mic up, 24kHz speaker down)

/// Same shape as the previous direct-to-Gemini pipeline — the wire format
/// hasn't changed, only who's on the other end of the WebSocket.
private actor InterviewAudioPipeline {

    private let inputEngine = AVAudioEngine()
    private let outputEngine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    private var converter: AVAudioConverter?
    private let captureFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
    )!
    private let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24_000,
        channels: 1,
        interleaved: true
    )!

    func start(_ onMicChunk: @escaping @Sendable (Data) -> Void) async throws {
        try configureSession()

        outputEngine.attach(player)
        outputEngine.connect(player, to: outputEngine.mainMixerNode, format: playbackFormat)
        try outputEngine.start()
        // Don't call player.play() yet — the first server audio chunk
        // triggers play() in `enqueueServerAudio`. Calling play() on an
        // empty queue makes the mixer render zero-byte cycles and the
        // audio subsystem spams `mBuffers[0].mDataByteSize (0)` warnings.

        let input = inputEngine.inputNode
        let micFormat = input.outputFormat(forBus: 0)
        guard let conv = AVAudioConverter(from: micFormat, to: captureFormat) else {
            throw NSError(domain: "InterviewAudioPipeline", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Couldn't build mic converter"])
        }
        converter = conv

        input.installTap(onBus: 0, bufferSize: 1024, format: micFormat) { buf, _ in
            guard let outBuf = AVAudioPCMBuffer(
                pcmFormat: self.captureFormat,
                frameCapacity: AVAudioFrameCount(self.captureFormat.sampleRate)
            ) else { return }
            var err: NSError?
            let status = conv.convert(to: outBuf, error: &err) { _, ioStatus in
                ioStatus.pointee = .haveData
                return buf
            }
            guard status != .error, outBuf.frameLength > 0,
                  let int16 = outBuf.int16ChannelData else { return }
            let byteCount = Int(outBuf.frameLength) * MemoryLayout<Int16>.size
            let data = Data(bytes: int16[0], count: byteCount)
            onMicChunk(data)
        }
        try inputEngine.start()
    }

    func stop() async {
        inputEngine.inputNode.removeTap(onBus: 0)
        inputEngine.stop()
        player.stop()
        outputEngine.stop()
    }

    func enqueueServerAudio(_ data: Data) async {
        let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Int16>.size)
        guard frameCount > 0,
              let buf = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: frameCount),
              let dst = buf.int16ChannelData?[0] else { return }
        buf.frameLength = frameCount
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            memcpy(dst, base, data.count)
        }
        player.scheduleBuffer(buf, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setPreferredSampleRate(16_000)
        try session.setPreferredIOBufferDuration(0.02)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }
}
