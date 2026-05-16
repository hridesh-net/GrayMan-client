import SwiftUI

// Maps to S1 in the React mockup: splash + Get Started + Sign In.

struct OnboardingView: View {
    @Environment(AppTheme.self) private var theme
    let goNext: () -> Void

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            Blobs(accent: theme.accent, opacity: 1.0)

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.shadowGrey, theme.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 82, height: 82)
                        .shadow(color: theme.accent.opacity(0.42), radius: 14, x: 0, y: 8)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 28)
                .accessibilityHidden(true)

                Text("GrayMan")
                    .scaledFont(size: 44, weight: .heavy, relativeTo: .largeTitle)
                    .foregroundStyle(Color.shadowGrey)
                    .tracking(-1.5)

                Text(theme.t("Digital identity for skilled workers", "कुशल कामगारों की डिजिटल पहचान",
                             mr: "कुशल कामगारांची डिजिटल ओळख",
                             te: "నైపుణ్య కార్మికుల డిజిటల్ గుర్తింపు",
                             ta: "திறன் தொழிலாளர்களின் டிஜிட்டல் அடையாளம்",
                             kn: "ಕೌಶಲ್ಯ ಕಾರ್ಮಿಕರ ಡಿಜಿಟಲ್ ಗುರುತು"))
                    .scaledFont(size: 16, relativeTo: .body)
                    .foregroundStyle(Color.mutedText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
                    .padding(.top, 8)

                Text("काम · सेतु")
                    .scaledFont(size: 13, weight: .bold, relativeTo: .footnote)
                    .foregroundStyle(theme.accent)
                    .tracking(0.6)
                    .padding(.top, 6)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: goNext) {
                        Text(theme.t("Get Started", "शुरू करें",
                                     mr: "सुरुवात करा", te: "ప్రారంభించు",
                                     ta: "தொடங்கு", kn: "ಪ್ರಾರಂಭಿಸಿ"))
                            .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(theme.accent)
                            )
                            .shadow(color: theme.accent.opacity(0.36), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel(theme.t("Get started", "शुरू करें",
                                                mr: "सुरुवात करा", te: "ప్రారంభించు",
                                                ta: "தொடங்கு", kn: "ಪ್ರಾರಂಭಿಸಿ"))
                    .accessibilityHint(theme.t("Begin onboarding to create your worker profile",
                                               "वर्कर प्रोफ़ाइल बनाने के लिए शुरू करें"))

                    Button(action: goNext) {
                        Text(theme.t("Sign In", "साइन इन",
                                     mr: "साइन इन करा", te: "సైన్ ఇన్",
                                     ta: "உள்நுழைய", kn: "ಸೈನ್ ಇನ್"))
                            .scaledFont(size: 15, weight: .semibold, relativeTo: .body)
                            .foregroundStyle(Color.shadowGrey)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.shadowGrey.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.98))
                    .accessibilityLabel(theme.t("Sign in", "साइन इन",
                                                mr: "साइन इन करा", te: "సైన్ ఇన్",
                                                ta: "உள்நுழைய", kn: "ಸೈನ್ ಇನ್"))
                    .accessibilityHint(theme.t("Sign in to an existing GrayMan account",
                                               "मौजूदा GrayMan अकाउंट में साइन इन करें"))

                    Text(theme.t("By continuing you agree to our Terms & Privacy",
                                 "जारी रखकर आप हमारी शर्तों और गोपनीयता से सहमत हैं"))
                        .scaledFont(size: 12, relativeTo: .caption)
                        .foregroundStyle(Color.dimText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    ForEach(AppLanguage.allCases.prefix(3), id: \.self) { lang in
                        languagePill(lang)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(AppLanguage.allCases.dropFirst(3), id: \.self) { lang in
                        languagePill(lang)
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func languagePill(_ lang: AppLanguage) -> some View {
        let on = theme.language == lang
        Button { theme.language = lang } label: {
            Text(lang.shortCode)
                .scaledFont(size: 13, weight: .bold, relativeTo: .footnote)
                .foregroundStyle(on ? .white : Color.shadowGrey)
                .frame(width: 52, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(on ? theme.accent : Color.soft)
                )
        }
        .buttonStyle(PressScaleStyle(scale: 0.94))
        .accessibilityLabel(lang.displayName)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
