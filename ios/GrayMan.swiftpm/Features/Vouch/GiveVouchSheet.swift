import SwiftUI

// Slide-up sheet for recording a voice-note endorsement (doc §2C — Vouch Score).
// Presented from ExploreView's vouch action button or the worker ProfileView.

struct GiveVouchSheet: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    let worker: Worker
    var workerService: WorkerService = .shared

    @State private var relationship: Int = 0
    @State private var rating: Int = 0
    @State private var isRecording = false
    @State private var recordingElapsed = 0
    @State private var hasRecording = false
    @State private var note = ""
    @State private var submitted = false
    @State private var submitting = false
    @State private var submitError: String? = nil

    private var relationships: [String] {
        [
            theme.t("We worked together", "हमने साथ काम किया"),
            theme.t("They worked for me", "इन्होंने मेरे लिए काम किया"),
            theme.t("I was their client", "मैं इनका ग्राहक था"),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.shadowGrey.opacity(0.18))
                .frame(width: 44, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 16)

            if submitted {
                successView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        workerHeader
                        relationshipSection
                        starSection
                        voiceSection
                        noteSection
                        submitButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Worker header

    private var workerHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(hex: worker.gradientStartHex), Color(hex: worker.gradientEndHex)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 52, height: 52)
                Text(worker.initials)
                    .scaledFont(size: 18, weight: .heavy, relativeTo: .headline)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(worker.name)
                    .scaledFont(size: 17, weight: .heavy, relativeTo: .headline)
                    .foregroundStyle(Color.shadowGrey)
                Text(worker.trade)
                    .scaledFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(Color.mutedText)
            }
            Spacer()
            VouchScoreRing(score: worker.vouchScore, size: 52)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Relationship picker

    private var relationshipSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(theme.t("How do you know them?", "आप इन्हें कैसे जानते हैं?"))
            VStack(spacing: 8) {
                ForEach(relationships.indices, id: \.self) { i in
                    let on = relationship == i
                    Button { relationship = i } label: {
                        HStack {
                            Text(relationships[i])
                                .scaledFont(size: 15, relativeTo: .body)
                                .foregroundStyle(Color.shadowGrey)
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? theme.accent : Color.dimText.opacity(0.4))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(on ? theme.accent.opacity(0.06) : Color.soft)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(on ? theme.accent.opacity(0.30) : .clear, lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(relationships[i])
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    // MARK: - Star rating

    private var starSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(theme.t("Rate their work", "इनके काम को रेट करें"))
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { star in
                    Button { rating = star } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 30))
                            .foregroundStyle(star <= rating ? Color(hex: "#F4A261") : Color.dimText.opacity(0.4))
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.88))
                    .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                    .accessibilityAddTraits(star <= rating ? [.isButton, .isSelected] : .isButton)
                }
                Spacer()
            }
        }
    }

    // MARK: - Voice note

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(theme.t("Voice note · optional · max 30s", "वॉयस नोट · वैकल्पिक · अधिकतम 30 सेकंड"))
            HStack(spacing: 16) {
                Button {
                    if isRecording {
                        isRecording = false
                        if recordingElapsed > 0 { hasRecording = true }
                    } else {
                        isRecording = true
                        recordingElapsed = 0
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color(hex: "#E63946") : theme.accent)
                            .frame(width: 60, height: 60)
                            .shadow(color: (isRecording ? Color(hex: "#E63946") : theme.accent).opacity(0.36),
                                    radius: 10, x: 0, y: 4)
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(isRecording ? 1.08 : 1.0)
                    .animation(isRecording
                        ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                        : .default,
                               value: isRecording)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRecording ? theme.t("Stop voice note", "वॉयस नोट रोकें") : theme.t("Record voice note", "वॉयस नोट रिकॉर्ड करें"))

                VStack(alignment: .leading, spacing: 4) {
                    if isRecording {
                        Text(theme.t("Recording… \(recordingElapsed)s / 30s", "रिकॉर्ड हो रहा है… \(recordingElapsed)s / 30s"))
                            .scaledFont(size: 14, weight: .semibold, relativeTo: .body)
                            .foregroundStyle(Color(hex: "#E63946"))
                    } else if hasRecording {
                        Text(theme.t("Voice note ready ✓", "वॉयस नोट तैयार ✓"))
                            .scaledFont(size: 14, weight: .semibold, relativeTo: .body)
                            .foregroundStyle(theme.accent)
                    } else {
                        Text(theme.t("Tap mic to record", "रिकॉर्ड करने के लिए माइक टैप करें"))
                            .scaledFont(size: 14, relativeTo: .body)
                            .foregroundStyle(Color.dimText)
                    }
                    Text(theme.t("Voice adds authenticity to your vouch", "वॉयस आपके Vouch को प्रामाणिक बनाता है"))
                        .scaledFont(size: 12, relativeTo: .caption)
                        .foregroundStyle(Color.dimText)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.soft))
        }
    }

    // MARK: - Optional text note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(theme.t("Short note · optional", "छोटी टिप्पणी · वैकल्पिक"))
            TextField(theme.t("e.g. Fixed our wiring in one day, very professional…", "जैसे: एक दिन में वायरिंग ठीक की, बहुत प्रोफ़ेशनल…"),
                      text: $note, axis: .vertical)
                .scaledFont(size: 15, relativeTo: .body)
                .foregroundStyle(Color.shadowGrey)
                .lineLimit(3, reservesSpace: true)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.soft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(note.isEmpty ? .clear : theme.accent.opacity(0.30), lineWidth: 1.5)
                        )
                )
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        VStack(spacing: 10) {
            if let submitError {
                Text(submitError)
                    .scaledFont(size: 12, weight: .semibold, relativeTo: .caption)
                    .foregroundStyle(Color(hex: "#E63946"))
                    .multilineTextAlignment(.center)
            }
            Button {
                guard rating > 0, !submitting else { return }
                submit()
            } label: {
                HStack(spacing: 8) {
                    if submitting {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .white.opacity(0.55))
                            .accessibilityHidden(true)
                    }
                    Text(submitting
                         ? theme.t("Submitting…", "भेज रहे हैं…")
                         : theme.t("Submit Vouch", "Vouch सबमिट करें"))
                        .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(rating > 0 ? theme.accent : Color.dimText.opacity(0.40))
                )
                .shadow(color: rating > 0 ? theme.accent.opacity(0.36) : .clear,
                        radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PressScaleStyle())
            .disabled(rating == 0 || submitting)
            .accessibilityLabel(theme.t("Submit vouch", "Vouch सबमिट करें"))
            .accessibilityHint(rating == 0 ? theme.t("Give a star rating first", "पहले स्टार रेटिंग दें") : "")
        }
    }

    private func submit() {
        submitError = nil
        submitting = true
        // Backend requires at least one skill index — use verified skill
        // indices if the worker has any, otherwise fall back to "all skills".
        let skillIndices: [Int] = {
            if !worker.verifiedTagIndices.isEmpty {
                return Array(worker.verifiedTagIndices).sorted()
            }
            return Array(0..<max(1, worker.tags.count))
        }()
        Task {
            defer { submitting = false }
            do {
                try await workerService.giveVouch(
                    toWorkerID: worker.id,
                    skillIndices: skillIndices
                )
                submitted = true
            } catch APIError.server(409, _) {
                // Already vouched — treat as success so the UX still feels
                // celebratory; the receiver score stays the same.
                submitted = true
            } catch {
                submitError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, theme.accent)
                .font(.system(size: 72))
                .accessibilityHidden(true)
            Text(theme.t("Vouch Sent!", "Vouch भेजा गया!"))
                .scaledFont(size: 28, weight: .heavy, relativeTo: .largeTitle)
                .foregroundStyle(Color.shadowGrey)
            Text(theme.t("Your endorsement boosts \(worker.name.split(separator: " ").first.map(String.init) ?? worker.name)'s Vouch Score.", "आपके Vouch से \(worker.name.split(separator: " ").first.map(String.init) ?? worker.name) का Vouch Score बढ़ेगा।"))
                .scaledFont(size: 15, relativeTo: .body)
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button { dismiss() } label: {
                Text(theme.t("Done", "हो गया"))
                    .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.accent))
            }
            .buttonStyle(PressScaleStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .accessibilityElement(children: .combine)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .scaledFont(size: 11, weight: .heavy, relativeTo: .caption2)
            .foregroundStyle(Color.dimText)
            .tracking(1.0)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Vouch Score Ring (shared between GiveVouchSheet and ProfileView)

struct VouchScoreRing: View {
    let score: Int   // 0–100
    var size: CGFloat = 64

    private var ringColor: Color {
        score >= 80 ? Color(hex: "#2D6A4F") : score >= 60 ? Color(hex: "#F4A261") : Color(hex: "#E63946")
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.shadowGrey.opacity(0.10), lineWidth: size * 0.08)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(ringColor, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.9), value: score)
            VStack(spacing: 1) {
                Text("\(score)")
                    .scaledFont(size: size * 0.30, weight: .heavy, relativeTo: .title2)
                    .foregroundStyle(Color.shadowGrey)
                Text("VOUCH")
                    .scaledFont(size: size * 0.12, weight: .heavy, relativeTo: .caption2)
                    .foregroundStyle(Color.dimText)
                    .tracking(0.5)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vouch score \(score) out of 100")
    }
}
