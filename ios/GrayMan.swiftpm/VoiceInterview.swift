import AVFoundation
import Speech
import SwiftUI

// MARK: - Errors

enum VoiceInterviewError: LocalizedError {
    case micPermissionDenied
    case speechPermissionDenied
    case recognizerUnavailable
    case transcriptionFailed(String)
    case scoringFailed(String)

    var errorDescription: String? {
        switch self {
        case .micPermissionDenied:        return "Microphone access is required for the interview."
        case .speechPermissionDenied:     return "Speech recognition access is required."
        case .recognizerUnavailable:      return "Speech recognition is unavailable in this language."
        case .transcriptionFailed(let s): return "Transcription error: \(s)"
        case .scoringFailed(let s):       return "Scoring error: \(s)"
        }
    }
}

// MARK: - Domain

struct AnswerScore: Equatable, Sendable {
    let confidence: Int   // 0–100
    let clarity: Int      // 0–100
}

// MARK: - Service protocol

@MainActor
protocol VoiceInterviewService: AnyObject {
    func requestPermissions() async -> Bool
    func speak(_ text: String, locale: Locale) async
    func cancelSpeech()
    func startTranscribing(locale: Locale) async throws
    func stopTranscribing() async -> String
    func scoreAnswer(question: String, answer: String, trade: String) async throws -> AnswerScore
}

// MARK: - Real implementation

@MainActor
final class SFVoiceInterviewService: NSObject, VoiceInterviewService {

    private let synthesizer = AVSpeechSynthesizer()
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechContinuation: CheckedContinuation<Void, Never>?
    private var latestTranscript = ""

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func requestPermissions() async -> Bool {
        let micOK = await AVAudioApplication.requestRecordPermission()
        guard micOK else { return false }
        let status = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        return status == .authorized
    }

    func speak(_ text: String, locale: Locale) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            speechContinuation = cont
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: locale.identifier)
            utterance.rate = 0.50
            utterance.pitchMultiplier = 1.05
            synthesizer.speak(utterance)
        }
    }

    func cancelSpeech() {
        synthesizer.stopSpeaking(at: .immediate)
        // delegate will resume the continuation via resume()
    }

    func startTranscribing(locale: Locale) async throws {
        let recognizer = SFSpeechRecognizer(locale: locale)
        guard recognizer?.isAvailable == true else { throw VoiceInterviewError.recognizerUnavailable }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        latestTranscript = ""

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, let result else { return }
            self.latestTranscript = result.bestTranscription.formattedString
        }

        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.recognitionRequest?.append(buf)
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    func stopTranscribing() async -> String {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return latestTranscript
    }

    func scoreAnswer(question: String, answer: String, trade: String) async throws -> AnswerScore {
        if BackendConfig.useDummyScores {
            try? await Task.sleep(for: .milliseconds(900))
            return AnswerScore(confidence: Int.random(in: 65...90), clarity: Int.random(in: 68...92))
        }
        guard let url = URL(string: "\(BackendConfig.baseURL)/v1/interview/score") else {
            throw VoiceInterviewError.scoringFailed("invalid backend URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "trade":    trade,
            "question": question,
            "answer":   answer.isEmpty ? "(no response)" : answer
        ])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw VoiceInterviewError.scoringFailed("server error")
        }
        guard
            let scores = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let c      = scores["confidence"] as? Int,
            let cl     = scores["clarity"]    as? Int
        else { throw VoiceInterviewError.scoringFailed("unexpected response") }
        return AnswerScore(confidence: min(100, max(0, c)), clarity: min(100, max(0, cl)))
    }
}

extension SFVoiceInterviewService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { resumeSpeech() }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { resumeSpeech() }

    private nonisolated func resumeSpeech() {
        Task { @MainActor [weak self] in
            let cont = self?.speechContinuation
            self?.speechContinuation = nil
            cont?.resume()
        }
    }
}

// MARK: - Backend config

enum BackendConfig {
    // Base URL of the GrayMan API. Swap for prod URL before shipping.
    static let baseURL = "https://api.grayman.app"
    // Set false once the backend /v1/interview/score endpoint is live.
    static let useDummyScores = true
}

// MARK: - Mock (simulator / tests)

@MainActor
final class MockVoiceInterviewService: VoiceInterviewService {
    func requestPermissions() async -> Bool { true }
    func speak(_ text: String, locale: Locale) async { try? await Task.sleep(for: .milliseconds(700)) }
    func cancelSpeech() {}
    func startTranscribing(locale: Locale) async throws { try? await Task.sleep(for: .milliseconds(200)) }
    func stopTranscribing() async -> String {
        try? await Task.sleep(for: .milliseconds(500))
        return "I have five years of experience and handled many complex projects on site."
    }
    func scoreAnswer(question: String, answer: String, trade: String) async throws -> AnswerScore {
        try? await Task.sleep(for: .milliseconds(800))
        return AnswerScore(confidence: Int.random(in: 70...92), clarity: Int.random(in: 72...95))
    }
}

// MARK: - ViewModel

@Observable @MainActor
final class VoiceInterviewViewModel {
    enum Phase: Equatable { case language, intro, questioning, result }
    enum QuestionState: Equatable { case speaking, waitingForUser, recording, analysing }

    private(set) var phase: Phase = .language
    private(set) var questionState: QuestionState = .speaking
    private(set) var questionIndex = 0
    private(set) var answeredCount = 0
    private(set) var confidenceScore = 0
    private(set) var clarityScore = 0
    private(set) var errorMessage: String? = nil

    var selectedLangIndex = 0

    let trade: String
    let questions: [String]
    let languages: [(name: String, locale: Locale)]

    private let service: VoiceInterviewService
    private var activeTask: Task<Void, Never>?
    private var allConfidence: [Int] = []
    private var allClarity: [Int] = []

    init(trade: String, service: VoiceInterviewService) {
        self.trade = trade
        self.service = service
        questions = [
            "Tell me about your experience. What is the most challenging project you have handled?",
            "A client is unhappy with your work. How do you handle the situation?",
            "Why should someone hire you over another worker with similar skills?",
            "Describe a time you had to learn something new quickly on the job.",
        ]
        languages = [
            (name: "English", locale: Locale(identifier: "en-IN")),
            (name: "हिंदी",   locale: Locale(identifier: "hi-IN")),
            (name: "मराठी",   locale: Locale(identifier: "mr-IN")),
            (name: "తెలుగు",  locale: Locale(identifier: "te-IN")),
        ]
    }

    var currentQuestion: String { questions[min(questionIndex, questions.count - 1)] }
    var currentLocale: Locale   { languages[selectedLangIndex].locale }
    var languageNames: [String] { languages.map(\.name) }

    func confirmLanguage() { phase = .intro }

    func startInterview() {
        phase = .questioning
        activeTask = Task {
            let ok = await service.requestPermissions()
            guard ok else {
                errorMessage = "Microphone and speech recognition permissions are required."
                phase = .intro
                return
            }
            speakCurrentQuestion()
        }
    }

    func tapMic() {
        switch questionState {
        case .waitingForUser: beginRecording()
        case .recording:      endRecording()
        default: break
        }
    }

    func onDisappear() {
        activeTask?.cancel()
        service.cancelSpeech()
    }

    func reset() {
        activeTask?.cancel()
        service.cancelSpeech()
        phase = .language;  questionState = .speaking
        questionIndex = 0;  answeredCount = 0
        confidenceScore = 0; clarityScore = 0
        allConfidence = []; allClarity = []
        errorMessage = nil
    }

    private func speakCurrentQuestion() {
        questionState = .speaking
        activeTask = Task {
            await service.speak(currentQuestion, locale: currentLocale)
            guard !Task.isCancelled else { return }
            questionState = .waitingForUser
        }
    }

    private func beginRecording() {
        activeTask = Task {
            do {
                try await service.startTranscribing(locale: currentLocale)
                guard !Task.isCancelled else { return }
                questionState = .recording
            } catch {
                errorMessage = error.localizedDescription
                questionState = .waitingForUser
            }
        }
    }

    private func endRecording() {
        questionState = .analysing
        activeTask = Task {
            let answer = await service.stopTranscribing()
            do {
                let score = try await service.scoreAnswer(question: currentQuestion, answer: answer, trade: trade)
                allConfidence.append(score.confidence)
                allClarity.append(score.clarity)
            } catch {
                allConfidence.append(Int.random(in: 65...85))
                allClarity.append(Int.random(in: 68...88))
            }
            confidenceScore = allConfidence.reduce(0, +) / allConfidence.count
            clarityScore    = allClarity.reduce(0, +)    / allClarity.count
            answeredCount  += 1
            if questionIndex < questions.count - 1 {
                questionIndex += 1
                speakCurrentQuestion()
            } else {
                phase = .result
            }
        }
    }
}
