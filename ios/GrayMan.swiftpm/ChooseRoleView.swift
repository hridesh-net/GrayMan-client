import SwiftUI

// SChoose from the React mockup. Two role cards:
//   - Professional → goes to RecordReelView
//   - Explore      → skips reel and goes straight to ProfileView

struct ChooseRoleView: View {
    @Environment(AppTheme.self) private var theme
    let name: String
    let goBack: () -> Void
    let goProfessional: () -> Void
    let goExplore: () -> Void

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            Blobs(accent: theme.accent, opacity: 0.8)

            VStack(alignment: .leading, spacing: 0) {
                Button(action: goBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.shadowGrey)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.soft)
                        )
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .accessibilityLabel(theme.t("Back", "वापस"))

                Spacer()

                VStack(alignment: .leading, spacing: 24) {
                    greeting
                    professionalCard
                    exploreCard
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(theme.t("WELCOME ABOARD", "स्वागत है"))
                .scaledFont(size: 13, weight: .heavy, relativeTo: .footnote)
                .foregroundStyle(theme.accent)
                .tracking(1.2)
            Text(theme.t("Hey \(name) 👋\nWhat brings\nyou here?", "नमस्ते \(name) 👋\nआप यहाँ\nकिसलिए आए?"))
                .scaledFont(size: 34, weight: .heavy, relativeTo: .largeTitle)
                .foregroundStyle(Color.shadowGrey)
                .tracking(-1.4)
                .lineSpacing(2)
            Text(theme.t("Choose how you'd like to use GrayMan", "GrayMan का उपयोग कैसे करना चाहते हैं?"))
                .scaledFont(size: 15, relativeTo: .subheadline)
                .foregroundStyle(Color.mutedText)
        }
        .accessibilityElement(children: .combine)
    }

    private var professionalCard: some View {
        Button(action: goProfessional) {
            professionalCardContent
        }
        .buttonStyle(PressScaleStyle(scale: 0.98))
        .accessibilityLabel(theme.t("I'm a Professional", "मैं प्रोफ़ेशनल हूं"))
        .accessibilityHint(theme.t("Create your verified work profile in 30 seconds", "30 सेकंड में सत्यापित वर्क प्रोफ़ाइल बनाएं"))
    }

    private var professionalCardContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.shadowGrey, theme.accent],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 52, height: 52)
                        .shadow(color: theme.accent.opacity(0.32),
                                radius: 8, x: 0, y: 4)
                    Image(systemName: "wrench.adjustable.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.t("I'm a Professional", "मैं प्रोफ़ेशनल हूं"))
                        .scaledFont(size: 17, weight: .heavy, relativeTo: .headline)
                        .foregroundStyle(Color.shadowGrey)
                        .tracking(-0.5)
                    Text(theme.t("Create your verified work profile. Electricians, plumbers, mechanics & 50+ trades.", "अपनी सत्यापित वर्क प्रोफ़ाइल बनाएं। इलेक्ट्रीशियन, प्लम्बर, मैकेनिक और 50+ ट्रेड।"))
                        .scaledFont(size: 13, relativeTo: .footnote)
                        .foregroundStyle(Color.mutedText)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.dimText)
                    .padding(.top, 18)
                    .accessibilityHidden(true)
            }
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.shadowGrey.opacity(0.08))
                .frame(height: 1)

            HStack(spacing: 8) {
                ForEach([
                    theme.t("Free", "मुफ़्त"),
                    theme.t("30 sec setup", "30 सेकंड सेटअप"),
                    theme.t("Get hired", "काम पाएं")
                ], id: \.self) { t in
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .heavy))
                        Text(t)
                            .scaledFont(size: 11, weight: .heavy, relativeTo: .caption2)
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.accent.opacity(0.10)))
                    .overlay(Capsule().stroke(theme.accent.opacity(0.22), lineWidth: 1))
                }
                Spacer()
            }
            .padding(.top, 14)
        }
        .padding(22)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var exploreCard: some View {
        Button(action: goExplore) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.soft)
                        .frame(width: 48, height: 48)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.shadowGrey)
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(theme.t("Explore Workers", "कामगार देखें"))
                        .scaledFont(size: 16, weight: .heavy, relativeTo: .headline)
                        .foregroundStyle(Color.shadowGrey)
                    Text(theme.t("Browse skilled professionals near you", "आस-पास के कुशल कामगार देखें"))
                        .scaledFont(size: 13, relativeTo: .footnote)
                        .foregroundStyle(Color.dimText)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.dimText)
                    .accessibilityHidden(true)
            }
            .padding(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.shadowGrey.opacity(0.12), lineWidth: 1.5)
            )
        }
        .buttonStyle(PressScaleStyle(scale: 0.98))
        .accessibilityLabel(theme.t("Explore workers", "कामगार देखें"))
        .accessibilityHint(theme.t("Browse skilled professionals near you", "आस-पास के कुशल कामगार देखें"))
    }
}
