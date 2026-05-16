import SwiftUI

struct VoiceInterviewView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var model: VoiceInterviewViewModel

    init(trade: String, service: VoiceInterviewService) {
        _model = State(wrappedValue: VoiceInterviewViewModel(trade: trade, service: service))
    }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            Blobs(accent: theme.accent, opacity: 0.5)

            VStack(spacing: 0) {
                navBar
                Group {
                    switch model.phase {
                    case .language:    languageScreen
                    case .intro:       introScreen
                    case .questioning: questionScreen
                    case .result:      resultScreen
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: model.phase)
            }
        }
        .onDisappear { model.onDisappear() }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.shadowGrey)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.soft))
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("Close interview")

            Spacer()
            Text("AI Interview")
                .scaledFont(size: 16, weight: .heavy, relativeTo: .headline)
                .foregroundStyle(Color.shadowGrey)
            Spacer()

            if model.phase == .questioning {
                Text("\(model.questionIndex + 1)/\(model.questions.count)")
                    .scaledFont(size: 13, weight: .semibold, relativeTo: .footnote)
                    .foregroundStyle(Color.mutedText)
                    .frame(width: 40, alignment: .trailing)
            } else {
                Color.clear.frame(width: 36)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Language selection

    private var languageScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.12))
                        .frame(width: 96, height: 96)
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 40))
                        .foregroundStyle(theme.accent)
                }
                Text("AI Voice Practice")
                    .scaledFont(size: 28, weight: .heavy, relativeTo: .largeTitle)
                    .foregroundStyle(Color.shadowGrey)
                Text("2-minute mock interview for \(model.trade).\nPractice in your language.")
                    .scaledFont(size: 15, relativeTo: .body)
                    .foregroundStyle(Color.mutedText)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 36)

            VStack(spacing: 8) {
                Text("CHOOSE LANGUAGE")
                    .scaledFont(size: 11, weight: .heavy, relativeTo: .caption2)
                    .foregroundStyle(Color.dimText)
                    .tracking(1.0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                ForEach(model.languageNames.indices, id: \.self) { i in
                    let on = model.selectedLangIndex == i
                    Button { model.selectedLangIndex = i } label: {
                        HStack {
                            Text(model.languageNames[i])
                                .scaledFont(size: 16, relativeTo: .body)
                                .foregroundStyle(on ? .white : Color.shadowGrey)
                            Spacer()
                            if on {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(on ? theme.accent : Color.soft)
                        )
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.97))
                    .padding(.horizontal, 24)
                    .accessibilityLabel(model.languageNames[i])
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                }
            }

            Spacer()

            Button { model.confirmLanguage() } label: {
                Text("Continue")
                    .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.accent))
                    .shadow(color: theme.accent.opacity(0.36), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PressScaleStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }

    // MARK: - Intro

    private var introScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            botAvatar(pulsing: false)
                .padding(.bottom, 32)

            Text("Ready when you are")
                .scaledFont(size: 24, weight: .heavy, relativeTo: .title2)
                .foregroundStyle(Color.shadowGrey)
                .padding(.bottom, 8)

            Text("I'll ask \(model.questions.count) questions about your work as a \(model.trade). The bot will read each question aloud — tap the mic when you're ready to answer.")
                .scaledFont(size: 15, relativeTo: .body)
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Spacer()

            VStack(spacing: 10) {
                infoRow(icon: "clock",         label: "About 2 minutes")
                infoRow(icon: "mic.fill",      label: "Speak naturally — no scripts needed")
                infoRow(icon: "chart.bar.fill", label: "Get Confidence + Clarity scores after")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button { model.startInterview() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill").accessibilityHidden(true)
                    Text("Start Interview")
                        .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.accent))
                .shadow(color: theme.accent.opacity(0.36), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PressScaleStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }

    // MARK: - Question screen

    private var questionScreen: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.shadowGrey.opacity(0.10))
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: geo.size.width * CGFloat(model.answeredCount) / CGFloat(model.questions.count))
                        .animation(.easeInOut(duration: 0.5), value: model.answeredCount)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .accessibilityLabel("Progress: \(model.answeredCount) of \(model.questions.count) answered")

            Spacer()

            botAvatar(pulsing: model.questionState == .speaking)
                .padding(.bottom, 28)

            if model.questionState == .analysing {
                HStack(spacing: 10) {
                    ProgressView().tint(theme.accent)
                    Text("Analysing your answer…")
                        .scaledFont(size: 15, relativeTo: .body)
                        .foregroundStyle(Color.mutedText)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.soft))
                .padding(.horizontal, 24)
            } else {
                Text(model.currentQuestion)
                    .scaledFont(size: 16, relativeTo: .body)
                    .foregroundStyle(Color.shadowGrey)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.soft))
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 10) {
                let isRecording = model.questionState == .recording
                let isBlocked   = model.questionState == .analysing || model.questionState == .speaking

                Button { model.tapMic() } label: {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color(hex: "#E63946") : theme.accent)
                            .frame(width: 72, height: 72)
                            .shadow(color: (isRecording ? Color(hex: "#E63946") : theme.accent).opacity(0.40),
                                    radius: 12, x: 0, y: 6)
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(isRecording ? 1.08 : 1.0)
                    .animation(isRecording
                        ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                        : .default,
                               value: isRecording)
                    .opacity(isBlocked ? 0.45 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(isBlocked)
                .accessibilityLabel(isRecording ? "Stop recording answer" : "Record answer")

                Group {
                    switch model.questionState {
                    case .speaking:      Text("Listening to question…")
                    case .waitingForUser: Text("Tap to answer")
                    case .recording:     Text("Tap to stop")
                    case .analysing:     Text("Analysing…")
                    }
                }
                .scaledFont(size: 13, relativeTo: .footnote)
                .foregroundStyle(Color.mutedText)

                if let err = model.errorMessage {
                    Text(err)
                        .scaledFont(size: 12, relativeTo: .caption)
                        .foregroundStyle(Color(hex: "#E63946"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .padding(.bottom, 44)
        }
    }

    // MARK: - Result

    private var resultScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.10))
                    .frame(width: 96, height: 96)
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 40))
                    .foregroundStyle(theme.accent)
            }
            .accessibilityHidden(true)
            .padding(.bottom, 20)

            Text("Interview Complete!")
                .scaledFont(size: 26, weight: .heavy, relativeTo: .largeTitle)
                .foregroundStyle(Color.shadowGrey)
                .padding(.bottom, 6)
            Text("Based on your \(model.questions.count) answers")
                .scaledFont(size: 15, relativeTo: .body)
                .foregroundStyle(Color.mutedText)
                .padding(.bottom, 28)

            VStack(spacing: 14) {
                scoreBar(label: "Communication Confidence", score: model.confidenceScore, color: theme.accent)
                scoreBar(label: "Persuasion Clarity",       score: model.clarityScore,    color: Color.verifiedBlue)
            }
            .padding(.horizontal, 24)

            Text("Practice regularly to improve your scores and get better job matches.")
                .scaledFont(size: 13, relativeTo: .footnote)
                .foregroundStyle(Color.dimText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 20)

            Spacer()

            HStack(spacing: 10) {
                Button { model.reset() } label: {
                    Text("Try Again")
                        .scaledFont(size: 15, weight: .semibold, relativeTo: .body)
                        .foregroundStyle(Color.shadowGrey)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.shadowGrey.opacity(0.15), lineWidth: 1.5))
                }
                .buttonStyle(PressScaleStyle(scale: 0.97))

                Button { dismiss() } label: {
                    Text("Done")
                        .scaledFont(size: 15, weight: .bold, relativeTo: .body)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.accent))
                        .shadow(color: theme.accent.opacity(0.34), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(PressScaleStyle(scale: 0.97))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }

    // MARK: - Helpers

    private func botAvatar(pulsing: Bool) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let ringOpacity: Double = pulsing ? max(0, 0.14 - Double(i) * 0.04) : 0
                let ringSize = CGFloat(88 + i * 22)
                Circle()
                    .stroke(theme.accent.opacity(ringOpacity), lineWidth: 1.5)
                    .frame(width: ringSize, height: ringSize)
                    .scaleEffect(pulsing ? 1.0 : 0.85)
                    .animation(
                        pulsing
                            ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double(i) * 0.35)
                            : .default,
                        value: pulsing)
            }
            Circle()
                .fill(LinearGradient(
                    colors: [Color.shadowGrey, theme.accent],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 80, height: 80)
                .shadow(color: theme.accent.opacity(0.36), radius: 12, x: 0, y: 6)
            Image(systemName: "waveform")
                .font(.system(size: 32))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }

    private func infoRow(icon: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(theme.accent)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(label)
                .scaledFont(size: 14, relativeTo: .body)
                .foregroundStyle(Color.mutedText)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.soft))
        .accessibilityElement(children: .combine)
    }

    private func scoreBar(label: String, score: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .scaledFont(size: 14, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(Color.shadowGrey)
                Spacer()
                Text("\(score)%")
                    .scaledFont(size: 22, weight: .heavy, relativeTo: .title3)
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.shadowGrey.opacity(0.10))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(score) / 100)
                        .animation(.easeOut(duration: 1.0).delay(0.3), value: score)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.soft))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(score) percent")
    }
}
