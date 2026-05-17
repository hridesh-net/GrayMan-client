import SwiftUI

// SName from the React mockup. Collects the user's display name.

struct NameEntryView: View {
    @Environment(AppTheme.self) private var theme
    let goBack: () -> Void
    let goNext: (String) -> Void

    @State private var name: String = ""
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool   { trimmed.count > 1 }
    private var firstName: String {
        trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            Blobs(accent: theme.accent, opacity: 0.6)

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

                VStack(alignment: .leading, spacing: 8) {
                    Text(theme.t("What should\nwe call you?", "आपको क्या\nबुलाएं?"))
                        .scaledFont(size: 32, weight: .heavy, relativeTo: .largeTitle)
                        .foregroundStyle(Color.shadowGrey)
                        .tracking(-1.3)
                        .lineSpacing(2)
                    Text(theme.t("This will appear on your work profile", "यह आपकी वर्क प्रोफ़ाइल पर दिखेगा"))
                        .scaledFont(size: 15, relativeTo: .subheadline)
                        .foregroundStyle(Color.mutedText)
                }
                .padding(.horizontal, 28)
                .padding(.top, 40)
                .padding(.bottom, 40)
                .accessibilityElement(children: .combine)

                TextField(theme.t("Your full name", "आपका पूरा नाम"), text: $name)
                    .focused($focused)
                    .scaledFont(size: 18, weight: .semibold, relativeTo: .body)
                    .foregroundStyle(Color.shadowGrey)
                    .textContentType(.name)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.soft)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isValid ? theme.accent : .clear, lineWidth: 2)
                    )
                    .padding(.horizontal, 28)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .onSubmit { if isValid { goNext(trimmed) } }
                    .accessibilityLabel(theme.t("Your full name", "आपका पूरा नाम"))
                    .accessibilityHint(theme.t("Enter the name that will appear on your worker profile", "वह नाम डालें जो आपकी प्रोफ़ाइल पर दिखेगा"))

                if isValid {
                    HStack(spacing: 8) {
                        Circle().fill(theme.accent).frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                        Text(theme.t("Looks great, \(firstName)!", "बहुत अच्छा, \(firstName)!"))
                            .scaledFont(size: 13, weight: .semibold, relativeTo: .footnote)
                            .foregroundStyle(theme.accent)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()

                Button(action: { if isValid { goNext(trimmed) } }) {
                    Text(theme.t("Continue", "जारी रखें"))
                        .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                        .foregroundStyle(isValid ? .white : Color.dimText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isValid ? theme.accent : Color.soft)
                        )
                        .shadow(
                            color: isValid ? theme.accent.opacity(0.36) : .clear,
                            radius: 12, x: 0, y: 6
                        )
                }
                .buttonStyle(PressScaleStyle())
                .disabled(!isValid)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .accessibilityLabel(theme.t("Continue", "जारी रखें"))
                .accessibilityHint(isValid ? "" : "Enter your name to continue")
            }
            .animation(.easeInOut(duration: 0.2), value: isValid)
        }
        .onAppear { focused = true }
        .voiceGuide(
            en: "Please tell us your name. We'll show this on your work profile " +
                "so clients know who they are hiring. Type your name and tap Continue.",
            hi: "कृपया अपना नाम लिखिए। यह आपकी वर्क प्रोफ़ाइल पर दिखेगा ताकि " +
                "ग्राहक जान सकें कि वे किसे हायर कर रहे हैं। नाम लिखकर Continue दबाइए।"
        )
    }
}
