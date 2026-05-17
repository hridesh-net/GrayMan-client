import SwiftUI

// AI Voice Interview — backend-mediated Gemini Live + RAG.
//
// Flow:
//   1. Worker picks language (English / Hindi / Hinglish).
//   2. iOS opens a WebSocket to /api/v1/interview/ws on our backend.
//      The backend authenticates the JWT, builds the system prompt
//      (with RAG context for the worker's trade), opens a server-side
//      Gemini Live session, and proxies audio in both directions.
//   3. iOS streams 16kHz PCM mic audio up + plays 24kHz PCM audio back.
//      Tool calls (submit_interview_score, lookup_trade_knowledge) are
//      intercepted on the backend — the client never sees them directly.
//   4. When scoring fires, the backend persists + sends a {"type":"scores"}
//      frame followed by {"type":"done"}.

struct VoiceInterviewView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    let trade: String

    @State private var model: InterviewSessionModel

    init(trade: String) {
        self.trade = trade
        _model = State(wrappedValue: InterviewSessionModel(trade: trade))
    }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            Blobs(accent: theme.accent, opacity: 0.45)

            VStack(spacing: 0) {
                navBar
                Group {
                    switch model.phase {
                    case .language: languageScreen
                    case .connecting: connectingScreen
                    case .live: liveScreen
                    case .result: resultScreen
                    case .failed: failedScreen
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: model.phase)
            }
        }
        .onDisappear { Task { await model.stop() } }
    }

    // MARK: - Nav

    private var navBar: some View {
        HStack {
            Button {
                Task { await model.stop() }
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.shadowGrey)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.soft))
            }
            .accessibilityLabel("Close interview")
            Spacer()
            Text(theme.t("AI Interview", "AI इंटरव्यू"))
                .scaledFont(size: 16, weight: .heavy, relativeTo: .headline)
                .foregroundStyle(Color.shadowGrey)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
    }

    // MARK: - Phases

    private var languageScreen: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 56))
                .foregroundStyle(theme.accent)
            Text(theme.t("Pick a language", "भाषा चुनें"))
                .scaledFont(size: 24, weight: .heavy, relativeTo: .title)
                .foregroundStyle(Color.shadowGrey)
            Text(theme.t("The interviewer will speak in this language. You can mix English freely.",
                         "इंटरव्यूअर इसी भाषा में बात करेगा। आप अंग्रेज़ी मिला सकते हैं।"))
                .scaledFont(size: 13, relativeTo: .footnote)
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            VStack(spacing: 10) {
                languageButton("English", code: "en")
                languageButton("हिंदी (Hindi)", code: "hi")
                languageButton("Hinglish (mix)", code: "hi-en")
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            Spacer()
            Text(theme.t("Interview takes ~4 minutes. Find a quiet spot.",
                         "इंटरव्यू ~4 मिनट का है। शांत जगह चुनें।"))
                .scaledFont(size: 12, relativeTo: .caption)
                .foregroundStyle(Color.dimText)
                .padding(.bottom, 32)
        }
    }

    private func languageButton(_ label: String, code: String) -> some View {
        Button {
            Task { await model.start(lang: code) }
        } label: {
            HStack {
                Text(label)
                    .scaledFont(size: 16, weight: .semibold, relativeTo: .body)
                    .foregroundStyle(Color.shadowGrey)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.soft))
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
    }

    private var connectingScreen: some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView().controlSize(.large).tint(theme.accent)
            Text(theme.t("Setting up your interviewer…", "इंटरव्यूअर तैयार हो रहा है…"))
                .scaledFont(size: 16, weight: .semibold, relativeTo: .body)
                .foregroundStyle(Color.shadowGrey)
            Spacer()
        }
    }

    private var liveScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            wavingOrb
            Text(stateLabel)
                .scaledFont(size: 18, weight: .heavy, relativeTo: .title2)
                .foregroundStyle(Color.shadowGrey)
            if !model.lastTextTurn.isEmpty {
                Text(model.lastTextTurn)
                    .scaledFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(Color.mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineLimit(3)
            }
            Spacer()
            Button {
                Task { await model.stop(); dismiss() }
            } label: {
                Text(theme.t("End Interview", "इंटरव्यू समाप्त करें"))
                    .scaledFont(size: 15, weight: .semibold, relativeTo: .body)
                    .foregroundStyle(Color.mutedText)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .overlay(
                        Capsule().stroke(Color.dimText.opacity(0.3), lineWidth: 1.5)
                    )
            }
            .padding(.bottom, 36)
        }
    }

    private var wavingOrb: some View {
        let speaking = model.isSpeaking
        return ZStack {
            Circle()
                .fill(speaking ? theme.accent.opacity(0.20) : theme.accent.opacity(0.08))
                .frame(width: 200, height: 200)
                .scaleEffect(speaking ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: speaking)
            Circle()
                .fill(theme.accent.opacity(0.55))
                .frame(width: 110, height: 110)
            Image(systemName: speaking ? "waveform" : "mic.fill")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var stateLabel: String {
        if model.isSpeaking {
            return theme.t("Interviewer is speaking…", "इंटरव्यूअर बोल रहे हैं…")
        }
        return theme.t("Your turn — speak naturally", "आपकी बारी — बोलिए")
    }

    private var resultScreen: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, theme.accent)
                .font(.system(size: 60))
            Text(theme.t("Interview complete!", "इंटरव्यू पूरा!"))
                .scaledFont(size: 24, weight: .heavy, relativeTo: .title)
                .foregroundStyle(Color.shadowGrey)
            if let s = model.scores {
                HStack(spacing: 14) {
                    scoreRing(label: theme.t("Confidence", "आत्मविश्वास"), value: s.confidence)
                    scoreRing(label: theme.t("Clarity", "स्पष्टता"), value: s.clarity)
                    scoreRing(label: theme.t("Skill", "कौशल"), value: s.tradeCompetence)
                }
                .padding(.top, 4)
                Text(s.summary)
                    .scaledFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(Color.mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28).padding(.top, 8)
            }
            Spacer()
            Button { dismiss() } label: {
                Text(theme.t("Done", "हो गया"))
                    .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.accent))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func scoreRing(label: String, value: Int) -> some View {
        VStack(spacing: 6) {
            VouchScoreRing(score: value, size: 70)
            Text(label)
                .scaledFont(size: 11, weight: .heavy, relativeTo: .caption2)
                .foregroundStyle(Color.dimText)
        }
    }

    private var failedScreen: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "#E63946"))
            Text(theme.t("Interview failed", "इंटरव्यू विफल"))
                .scaledFont(size: 18, weight: .heavy, relativeTo: .title3)
                .foregroundStyle(Color.shadowGrey)
            Text(model.errorMessage ?? "")
                .scaledFont(size: 13, relativeTo: .footnote)
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
            Button { dismiss() } label: {
                Text(theme.t("Close", "बंद करें"))
                    .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 17)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.accent))
            }
            .padding(.horizontal, 24).padding(.bottom, 32)
        }
    }
}

// MARK: - View model

@Observable @MainActor
final class InterviewSessionModel {
    enum Phase: Equatable { case language, connecting, live, result, failed }

    let trade: String
    private(set) var phase: Phase = .language
    private(set) var session: InterviewSession?
    private(set) var scores: InterviewScores?
    private(set) var errorMessage: String?

    var lastTextTurn: String { session?.lastTextTurn ?? "" }
    var isSpeaking: Bool {
        if case .speaking = session?.state { return true }
        return false
    }

    init(trade: String) { self.trade = trade }

    func start(lang: String) async {
        phase = .connecting
        guard let token = TokenStore.shared.token else {
            errorMessage = "You must be signed in to start an interview."
            phase = .failed
            return
        }
        do {
            let live = try InterviewSession(trade: trade, lang: lang, token: token)
            live.onScores = { [weak self] s in
                guard let self else { return }
                self.scores = s
                // Backend persists scores server-side. Once we receive
                // them, transition to the result screen and let the
                // session close itself on the {"done"} frame.
                Task { await MainActor.run { self.phase = .result } }
            }
            live.onError = { [weak self] msg in
                guard let self else { return }
                self.errorMessage = msg
                self.phase = .failed
            }
            session = live
            await live.start()
            phase = .live
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            phase = .failed
        }
    }

    func stop() async {
        await session?.stop()
    }
}
