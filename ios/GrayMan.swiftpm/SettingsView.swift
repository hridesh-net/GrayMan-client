import SwiftUI

// Settings screen — accessible from the Settings tab in ProfileView's tab bar.
// For now: language switcher (English / हिंदी). More languages added later.

struct SettingsView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            Blobs(accent: theme.accent, opacity: 0.45)

            VStack(spacing: 0) {
                navBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        languageSection
                        appearanceSection
                        aboutSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.shadowGrey)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.soft)
                    )
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("Close settings")

            Spacer()

            Text(theme.t("Settings", "सेटिंग्स"))
                .scaledFont(size: 16, weight: .heavy, relativeTo: .headline)
                .foregroundStyle(Color.shadowGrey)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Language section

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel(theme.t("Language", "भाषा"))

            VStack(spacing: 0) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    let on = theme.language == lang
                    Button { theme.language = lang } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(on ? theme.accent : Color.soft)
                                    .frame(width: 40, height: 40)
                                Text(lang.shortCode)
                                    .scaledFont(size: 15, weight: .heavy, relativeTo: .body)
                                    .foregroundStyle(on ? .white : Color.mutedText)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.displayName)
                                    .scaledFont(size: 16, weight: .semibold, relativeTo: .body)
                                    .foregroundStyle(Color.shadowGrey)
                                Text(lang.displayName)
                                    .scaledFont(size: 12, relativeTo: .caption)
                                    .foregroundStyle(Color.dimText)
                            }

                            Spacer()

                            if on {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(theme.accent)
                                    .font(.system(size: 20))
                                    .accessibilityHidden(true)
                            } else {
                                Circle()
                                    .stroke(Color.dimText.opacity(0.35), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(lang.displayName)
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)

                    if lang != AppLanguage.allCases.last {
                        Divider()
                            .padding(.leading, 70)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
            )

        }
    }

    // MARK: - Appearance section (accent colour redirect)

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel(theme.t("Appearance", "रूप-रंग"))

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 22, height: 22)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.t("Accent colour", "थीम रंग"))
                        .scaledFont(size: 16, weight: .semibold, relativeTo: .body)
                        .foregroundStyle(Color.shadowGrey)
                    Text(theme.t("Use the 🎨 button on any screen to change",
                                 "किसी भी स्क्रीन पर 🎨 बटन से बदलें"))
                        .scaledFont(size: 12, relativeTo: .caption)
                        .foregroundStyle(Color.dimText)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
            )
        }
    }

    // MARK: - About section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel(theme.t("About", "के बारे में"))

            VStack(spacing: 0) {
                aboutRow(icon: "bolt.fill",
                         label: theme.t("GrayMan", "GrayMan"),
                         detail: theme.t("Version 1.0", "संस्करण 1.0"))
                Divider().padding(.leading, 56)
                aboutRow(icon: "doc.text.fill",
                         label: theme.t("Privacy Policy", "गोपनीयता नीति"),
                         detail: nil)
                Divider().padding(.leading, 56)
                aboutRow(icon: "hand.raised.fill",
                         label: theme.t("Terms of Service", "सेवा की शर्तें"),
                         detail: nil)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
            )
        }
    }

    private func aboutRow(icon: String, label: String, detail: String?) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.soft)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.shadowGrey)
                    .accessibilityHidden(true)
            }
            Text(label)
                .scaledFont(size: 15, relativeTo: .body)
                .foregroundStyle(Color.shadowGrey)
            Spacer()
            if let detail {
                Text(detail)
                    .scaledFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(Color.dimText)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dimText)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label + (detail.map { ", \($0)" } ?? ""))
    }

    // MARK: - Helper

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .scaledFont(size: 11, weight: .heavy, relativeTo: .caption2)
            .foregroundStyle(Color.dimText)
            .tracking(1.0)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
