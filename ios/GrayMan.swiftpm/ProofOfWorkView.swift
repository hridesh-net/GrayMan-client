import SwiftUI

// Proof-of-Work (Time-Lapse) Reels — doc §3B.
// Workers capture "Day 1 → Done" photo sessions; the app compiles them
// into a time-lapse reel for clients to review.
// Presented as fullScreenCover from the worker's own profile.

struct ProofOfWorkView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var sessions: [POWSession] = POWSession.samples
    @State private var showAddSheet = false
    @State private var newCaption = ""

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            Blobs(accent: theme.accent, opacity: 0.45)

            VStack(spacing: 0) {
                navBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        header
                        if sessions.isEmpty {
                            emptyState
                        } else {
                            timeline
                            if sessions.count >= 2 {
                                compileButton
                            }
                        }
                        addButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) { addSessionSheet }
    }

    // MARK: - Nav

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
            .accessibilityLabel(theme.t("Close", "बंद करें"))
            Spacer()
            Text(theme.t("Proof of Work", "काम का सबूत"))
                .scaledFont(size: 16, weight: .heavy, relativeTo: .headline)
                .foregroundStyle(Color.shadowGrey)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(theme.t("Day 1 → Done", "दिन 1 → पूरा"))
                .scaledFont(size: 26, weight: .heavy, relativeTo: .largeTitle)
                .foregroundStyle(Color.shadowGrey)
            Text(theme.t("Document each stage of a project. We'll compile your photos into a time-lapse reel clients can trust.", "प्रोजेक्ट का हर चरण दर्ज करें। हम आपकी फ़ोटो से एक टाइम-लैप्स रील बनाएंगे जिस पर ग्राहक भरोसा कर सकें।"))
                .scaledFont(size: 14, relativeTo: .body)
                .foregroundStyle(Color.mutedText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { idx, session in
                HStack(alignment: .top, spacing: 16) {
                    // Spine
                    VStack(spacing: 0) {
                        ZStack {
                            Circle().fill(theme.accent).frame(width: 36, height: 36)
                            Text(session.emoji)
                                .font(.system(size: 17))
                        }
                        if idx < sessions.count - 1 {
                            Rectangle()
                                .fill(theme.accent.opacity(0.20))
                                .frame(width: 2)
                                .frame(minHeight: 60)
                        }
                    }
                    .frame(width: 36)

                    // Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(session.dayLabel)
                                .scaledFont(size: 11, weight: .heavy, relativeTo: .caption2)
                                .foregroundStyle(theme.accent)
                                .tracking(0.8)
                            Spacer()
                            Text(session.date)
                                .scaledFont(size: 12, relativeTo: .caption)
                                .foregroundStyle(Color.dimText)
                        }
                        Text(session.caption)
                            .scaledFont(size: 15, weight: .semibold, relativeTo: .body)
                            .foregroundStyle(Color.shadowGrey)

                        // Photo placeholder
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.soft)
                                .frame(height: 130)
                            VStack(spacing: 6) {
                                Image(systemName: "photo")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color.dimText)
                                    .accessibilityHidden(true)
                                Text(theme.t("Photo · \(session.date)", "फ़ोटो · \(session.date)"))
                                    .scaledFont(size: 12, relativeTo: .caption)
                                    .foregroundStyle(Color.dimText)
                            }
                        }
                    }
                    .padding(.bottom, idx < sessions.count - 1 ? 20 : 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(session.dayLabel): \(session.caption)")
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }

    // MARK: - Compile button

    private var compileButton: some View {
        Button {} label: {
            HStack(spacing: 10) {
                Image(systemName: "film.stack")
                    .font(.system(size: 18))
                    .accessibilityHidden(true)
                Text(theme.t("Compile Time-Lapse Reel", "टाइम-लैप्स रील बनाएं"))
                    .scaledFont(size: 15, weight: .bold, relativeTo: .body)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.shadowGrey, theme.accent],
                        startPoint: .leading, endPoint: .trailing
                    ))
            )
            .shadow(color: theme.accent.opacity(0.34), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(theme.t("Compile time-lapse reel from all sessions", "सभी सत्रों से टाइम-लैप्स रील बनाएं"))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.on.rectangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(theme.accent.opacity(0.60))
                .accessibilityHidden(true)
            Text(theme.t("No sessions yet", "अभी कोई सत्र नहीं"))
                .scaledFont(size: 17, weight: .heavy, relativeTo: .headline)
                .foregroundStyle(Color.shadowGrey)
            Text(theme.t("Add your first progress photo. After 2+ sessions, we'll compile them into a time-lapse reel.", "अपनी पहली प्रगति फ़ोटो जोड़ें। 2+ सत्रों के बाद, हम उन्हें टाइम-लैप्स रील में बनाएंगे।"))
                .scaledFont(size: 14, relativeTo: .body)
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.soft))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Add button

    private var addButton: some View {
        Button { showAddSheet = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16))
                    .accessibilityHidden(true)
                Text(theme.t("Add Today's Progress", "आज की प्रगति जोड़ें"))
                    .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
            }
            .foregroundStyle(theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.accent.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(theme.t("Add today's progress session", "आज का प्रगति सत्र जोड़ें"))
    }

    // MARK: - Add session sheet

    private var addSessionSheet: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.shadowGrey.opacity(0.18))
                .frame(width: 44, height: 5)
                .padding(.top, 10)

            Text(theme.t("Day \(sessions.count + 1)", "दिन \(sessions.count + 1)"))
                .scaledFont(size: 22, weight: .heavy, relativeTo: .title2)
                .foregroundStyle(Color.shadowGrey)

            // Photo placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.soft)
                    .frame(height: 180)
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.accent.opacity(0.70))
                        .accessibilityHidden(true)
                    Text(theme.t("Tap to take / choose photo", "फ़ोटो लेने / चुनने के लिए टैप करें"))
                        .scaledFont(size: 14, relativeTo: .body)
                        .foregroundStyle(Color.dimText)
                }
            }
            .padding(.horizontal, 24)

            TextField(theme.t("What did you complete today?", "आज आपने क्या पूरा किया?"), text: $newCaption)
                .scaledFont(size: 15, relativeTo: .body)
                .foregroundStyle(Color.shadowGrey)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.soft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(newCaption.isEmpty ? .clear : theme.accent.opacity(0.30), lineWidth: 1.5)
                        )
                )
                .padding(.horizontal, 24)

            Button {
                let caption = newCaption.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !caption.isEmpty else { return }
                sessions.append(POWSession(
                    dayLabel: "Day \(sessions.count + 1)",
                    caption: caption,
                    emoji: "📸",
                    date: "Today"
                ))
                newCaption = ""
                showAddSheet = false
            } label: {
                Text(theme.t("Save Progress", "प्रगति सेव करें"))
                    .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                    .foregroundStyle(newCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.dimText : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(newCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  ? Color.dimText.opacity(0.30) : theme.accent)
                    )
            }
            .buttonStyle(PressScaleStyle())
            .disabled(newCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, 24)

            Spacer()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Data model

struct POWSession: Identifiable, Sendable {
    let id: UUID = UUID()
    let dayLabel: String
    let caption: String
    let emoji: String
    let date: String

    static let samples: [POWSession] = [
        POWSession(dayLabel: "Day 1", caption: "Site assessment & planning", emoji: "📐", date: "12 May"),
        POWSession(dayLabel: "Day 2", caption: "Panel installation started", emoji: "⚡", date: "13 May"),
        POWSession(dayLabel: "Day 3", caption: "Wiring 60% complete", emoji: "🔌", date: "14 May"),
    ]
}
