# Voice Interview — Architecture & Implementation Guide

## The latency problem

The naive approach to an AI voice interview uses three serial network calls:

```
User speaks
    → STT API        300–800 ms
    → LLM API        500–2000 ms
    → TTS API        200–500 ms
    → User hears
                     ─────────────
Total per exchange:  1–3 seconds (3G: 3–6 seconds)
```

The product doc states: *"If video buffering exceeds 3 seconds on Tier 3 (3G/Low 4G) networks, the platform fails."* A 3-second interview response delay triggers that failure on every turn.

---

## The solution: end-to-end audio streaming

Skip STT + TTS entirely. Use a model that accepts raw audio in and streams raw audio back over a single persistent WebSocket. The user hears the AI begin speaking before they have even finished their own sentence.

```
User speaks
    → PCM audio chunks → WebSocket → Gemini Live API
                                             ↓
User hears ← PCM audio chunks ← WebSocket ←┘

Total perceived latency: 300–500 ms
```

---

## API comparison

| API | Latency | Hindi | Cost estimate | Status |
|---|---|---|---|---|
| **Gemini Live API** | 300–500 ms | ✅ Full support | ~$0.01–0.05 / session | Preview (mid-2026) |
| OpenAI Realtime API | 200–300 ms | ❌ English only | ~$0.30 / min | GA |
| ElevenLabs Conversational AI | ~500 ms | ⚠️ Limited | ~$0.10 / min | GA |
| Traditional pipeline (SFSpeechRecognizer + Gemini Flash + AVSpeechSynthesizer) | 1–3 s | ✅ Full support | ~$0.001 / session | GA |

**Choice: Gemini Live API.** It is the only option with native Hindi, sub-500 ms latency, and reasonable cost at the scale of Tier 2/3 Indian workers.

---

## iOS architecture

### Audio session setup

Must be configured before starting the WebSocket. The session must support simultaneous capture and playback.

```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playAndRecord,
                         mode: .voiceChat,
                         options: [.defaultToSpeaker, .allowBluetooth])
try session.setActive(true)
```

### Two-engine design

Use a single `AVAudioEngine` with separate nodes for input capture and output playback.

```
Microphone
    └── AVAudioEngine (inputNode)
            └── installTap → PCM buffer → encode → WebSocket send

WebSocket receive → decode PCM → AVAudioPlayerNode
                                        └── AVAudioEngine (outputNode)
                                                └── Speaker
```

### GeminiLiveSession class (to be built)

This class owns the WebSocket and both audio paths. `VoiceInterviewView` holds one instance and reacts to its `@Observable` state.

```swift
@Observable @MainActor
final class GeminiLiveSession {

    enum State { case idle, connecting, listening, speaking, analysing, ended }

    private(set) var state: State = .idle
    private(set) var transcript: String = ""        // running transcript for display
    private(set) var confidenceScore: Int = 0
    private(set) var clarityScore: Int = 0

    private var socket: URLSessionWebSocketTask?
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    func start(trade: String, language: AppLanguage) async { ... }
    func stop() async { ... }

    private func sendAudioChunk(_ buffer: AVAudioPCMBuffer) { ... }
    private func receiveLoop() { ... }
    private func handleMessage(_ data: Data) { ... }
}
```

### WebSocket message protocol (Gemini Live)

All messages are JSON envelopes. Refer to the [official docs](https://ai.google.dev/gemini-api/docs/live) for the exact schema — the protocol can change during preview.

**Session setup (send once on connect):**
```json
{
  "setup": {
    "model": "models/gemini-2.0-flash-live-001",
    "generation_config": {
      "response_modalities": ["AUDIO"],
      "speech_config": {
        "voice_config": {
          "prebuilt_voice_config": { "voice_name": "Aoede" }
        }
      }
    },
    "system_instruction": {
      "parts": [{ "text": "<interview system prompt>" }]
    }
  }
}
```

**Sending audio (each chunk):**
```json
{
  "realtime_input": {
    "media_chunks": [{
      "data": "<base64-encoded PCM16 at 16 kHz>",
      "mime_type": "audio/pcm;rate=16000"
    }]
  }
}
```

**Receiving audio (from Gemini):**
```json
{
  "serverContent": {
    "modelTurn": {
      "parts": [{
        "inlineData": {
          "mimeType": "audio/pcm;rate=24000",
          "data": "<base64 PCM>"
        }
      }]
    }
  }
}
```

**Turn completion signal:**
```json
{ "serverContent": { "turnComplete": true } }
```

### Audio format

| Direction | Format | Sample rate |
|---|---|---|
| Mic → Gemini | PCM 16-bit, mono | 16 000 Hz |
| Gemini → Speaker | PCM 16-bit, mono | 24 000 Hz |

`AVAudioEngine`'s input node typically runs at 44 100 or 48 000 Hz on iOS. You must downsample the captured buffer to 16 000 Hz before sending. Use `AVAudioConverter` for this.

---

## System prompt design

The system prompt controls the full interview flow. Gemini Live runs it autonomously — no turn-management code needed in the app.

```
You are an AI interviewer for GrayMan, a platform for skilled workers in India.

Language: {hindi | english} — respond only in this language throughout.
Worker's trade: {trade}

Interview structure:
1. Greet the worker warmly by their trade (e.g. "नमस्ते, क्या आप एक electrician हैं?")
2. Ask exactly 4 questions from this list, one at a time. Wait for their answer before proceeding.
   - Tell me about your experience. What is the most challenging project you have handled?
   - A client is unhappy with your work. How do you handle the situation?
   - Why should someone hire you over another worker with similar skills?
   - Describe a time you had to learn something new quickly on the job.
3. After all 4 answers, say a closing line, then output a JSON block (do not speak this):
   SCORE_JSON: {"confidence": <0-100>, "clarity": <0-100>, "summary": "<one line>"}

Scoring criteria:
- confidence: how clearly and assertively they describe their skills and experience
- clarity: how easy it is to understand their answers; relevance to the question
```

### Extracting the score

Parse `SCORE_JSON:` out of the final transcript chunk:

```swift
private func handleMessage(_ data: Data) {
    // ... decode audio and play it ...

    if let text = extractTranscript(from: data),
       let range = text.range(of: "SCORE_JSON:"),
       let jsonData = text[range.upperBound...].trimmingCharacters(in: .whitespaces).data(using: .utf8),
       let score = try? JSONDecoder().decode(InterviewScore.self, from: jsonData) {
        confidenceScore = score.confidence
        clarityScore    = score.clarity
        state = .ended
    }
}
```

---

## VoiceInterviewView changes required

The current `VoiceInterviewView.swift` UI is complete and correct. Only the mock internals need replacing:

| Current (stub) | Replace with |
|---|---|
| `@State private var isRecording`, `@State private var analysing` | `@State private var session = GeminiLiveSession()` |
| Mic button toggles `isRecording` | Mic button calls `session.start(trade:language:)` / `session.stop()` |
| Fake `Task.sleep(1.6s)` | `session.state` drives bot avatar pulsing + analysing spinner |
| `confidenceScore = Int.random(...)` | Read from `session.confidenceScore` / `session.clarityScore` |
| Phase transitions hardcoded | Drive from `session.state` changes |

The language picker already sets `selectedLang`. Pass `AppLanguage.allCases[selectedLang]` into `session.start()`.

---

## Prerequisites

- Google AI Studio API key with Gemini Live access (apply at [aistudio.google.com](https://aistudio.google.com))
- `NSSpeechRecognitionUsageDescription` in Info.plist — already present via camera/mic capability in Package.swift
- `NSMicrophoneUsageDescription` — already declared
- Add `Privacy - Speech Recognition Usage Description` key before shipping

## Known constraints (preview period)

- Gemini Live WebSocket protocol schema may change before GA — pin to a specific model version string
- Concurrent session limit per API key during preview: check current quota in AI Studio
- The `voice_name` field controls which voice Gemini uses; test `Aoede`, `Charon`, `Kore`, `Fenrir` for the most natural Hindi output
- Audio latency spikes on congested networks — add a visual buffer indicator in `GeminiLiveSession` so the UI can show "reconnecting…" rather than a frozen bot avatar
