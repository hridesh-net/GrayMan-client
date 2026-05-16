import SwiftUI

// Maps to S2 in the React mockup: phone number entry → OTP screen.
// State is owned by PhoneAuthViewModel; the view is purely declarative.

struct PhoneAuthView: View {
    @Environment(AppTheme.self) private var theme
    let goBack: () -> Void
    let goNext: () -> Void

    @State private var model: PhoneAuthViewModel
    @FocusState private var phoneFocused: Bool
    @FocusState private var otpFocused: Bool

    init(model: PhoneAuthViewModel,
         goBack: @escaping () -> Void,
         goNext: @escaping () -> Void) {
        _model = State(wrappedValue: model)
        self.goBack = goBack
        self.goNext = goNext
    }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            Blobs(accent: theme.accent, opacity: 0.6)

            VStack(alignment: .leading, spacing: 0) {
                backButton

                headline
                    .padding(.horizontal, 28)
                    .padding(.top, 36)
                    .padding(.bottom, 36)

                if model.stage == .otp {
                    otpInputSection
                } else {
                    phoneInputSection
                }

                if let error = model.errorMessage {
                    Text(error)
                        .scaledFont(size: 13, weight: .semibold, relativeTo: .footnote)
                        .foregroundStyle(Color(hex: "#E63946"))
                        .padding(.horizontal, 28)
                        .padding(.top, 14)
                        .accessibilityAddTraits(.isStaticText)
                }

                Spacer()

                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .onAppear { phoneFocused = true }
    }

    private var backButton: some View {
        Button {
            if model.stage == .otp { model.backToPhone() } else { goBack() }
        } label: {
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
        .accessibilityLabel(model.stage == .otp ? theme.t("Back to phone number entry", "फ़ोन नंबर पर वापस जाएं") : theme.t("Back", "वापस"))
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(model.stage == .otp ? theme.t("Enter OTP", "OTP डालें") : theme.t("Your number", "आपका नंबर"))
                .scaledFont(size: 30, weight: .heavy, relativeTo: .largeTitle)
                .foregroundStyle(Color.shadowGrey)
                .tracking(-1)

            Text(model.stage == .otp
                 ? theme.t("Code sent to \(model.phone.e164)", "\(model.phone.e164) पर कोड भेजा गया")
                 : theme.t("We'll send a verification code", "हम एक सत्यापन कोड भेजेंगे"))
                .scaledFont(size: 15, relativeTo: .subheadline)
                .foregroundStyle(Color.mutedText)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Phone input row

    private var phoneInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                countryChip

                TextField(theme.t("Mobile number", "मोबाइल नंबर"), text: $model.national)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($phoneFocused)
                    .scaledFont(size: 17, weight: .medium, relativeTo: .body)
                    .foregroundStyle(Color.shadowGrey)
                    .tracking(0.7)
                    .submitLabel(.send)
                    .onSubmit { Task { await model.sendCode() } }
                    .accessibilityLabel(theme.t("Mobile number", "मोबाइल नंबर"))
                    .accessibilityHint("Enter your 10-digit phone number")

                Spacer()

                if model.canSendCode {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(theme.accent)
                            .frame(width: 40, height: 40)
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    .accessibilityHidden(true)
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 4)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.soft)
            )

            Text(theme.t("MOBILE NUMBER", "मोबाइल नंबर"))
                .scaledFont(size: 11, weight: .heavy, relativeTo: .caption2)
                .foregroundStyle(Color.dimText)
                .tracking(0.8)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 28)
    }

    private var countryChip: some View {
        HStack(spacing: 6) {
            Text("🇮🇳")
            Text(model.countryCode)
                .scaledFont(size: 14, weight: .heavy, relativeTo: .footnote)
                .foregroundStyle(Color.shadowGrey)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.dimText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Country code \(model.countryCode), India")
    }

    // MARK: - OTP boxes

    private var otpInputSection: some View {
        VStack(spacing: 20) {
            otpBoxes

            HStack(spacing: 10) {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(theme.t("Auto-reading code from messages…", "संदेशों से कोड ऑटो-पढ़ रहे हैं…"))
                    .scaledFont(size: 13, weight: .semibold, relativeTo: .footnote)
                    .foregroundStyle(theme.accent)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.accent.opacity(0.08))
            )
            .padding(.horizontal, 28)

            HStack(spacing: 4) {
                Spacer()
                Text(theme.t("Didn't get it?", "नहीं मिला?"))
                    .scaledFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(Color.dimText)
                Button(theme.t("Resend code", "कोड दोबारा भेजें")) {
                    Task { await model.sendCode() }
                }
                .scaledFont(size: 13, weight: .bold, relativeTo: .footnote)
                .foregroundStyle(theme.accent)
                .accessibilityLabel(theme.t("Resend verification code", "सत्यापन कोड दोबारा भेजें"))
                Spacer()
            }
        }
        .onAppear { otpFocused = true }
    }

    private var otpBoxes: some View {
        ZStack {
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    let char = i < model.code.count
                        ? String(model.code[model.code.index(model.code.startIndex, offsetBy: i)])
                        : ""
                    let isActive = i == model.code.count
                    let isFilled = !char.isEmpty

                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isActive ? theme.accent.opacity(0.08) : Color.soft)
                        if isActive {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(theme.accent, lineWidth: 2)
                        }
                        Text(char)
                            .scaledFont(size: 32, weight: .heavy, relativeTo: .largeTitle)
                            .foregroundStyle(isFilled ? Color.shadowGrey : Color.shadowGrey.opacity(0.3))
                    }
                    .frame(width: 70, height: 78)
                }
            }
            .accessibilityHidden(true)

            // Invisible TextField that drives `model.code` and surfaces the
            // OS one-time-code autofill suggestion.
            TextField("", text: $model.code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($otpFocused)
                .opacity(0.001)
                .frame(maxWidth: .infinity)
                .frame(height: 78)
                .onChange(of: model.code) { _, new in
                    let digits = new.filter(\.isNumber)
                    let trimmed = String(digits.prefix(4))
                    if trimmed != model.code { model.code = trimmed }
                }
                .accessibilityLabel("One-time passcode, 4 digits")
                .accessibilityValue(model.code.isEmpty ? "empty" : model.code)
                .accessibilityHint("Enter the 4-digit code we sent you")
        }
        .contentShape(Rectangle())
        .onTapGesture { otpFocused = true }
    }

    // MARK: - Continue button

    @ViewBuilder
    private var continueButton: some View {
        let isBusy = model.status == .sending || model.status == .verifying
        let isEnabled = model.stage == .otp ? model.canVerify : model.canSendCode

        VStack(spacing: 12) {
            Button {
                Task {
                    if model.stage == .otp {
                        let ok = await model.verifyCode()
                        if ok { goNext() }
                    } else {
                        await model.sendCode()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(continueLabel)
                        .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isEnabled ? theme.accent : Color.dimText.opacity(0.4))
                )
                .shadow(color: isEnabled ? theme.accent.opacity(0.36) : .clear,
                        radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PressScaleStyle())
            .disabled(!isEnabled || isBusy)
            .accessibilityLabel(continueAccessibilityLabel)
            .accessibilityHint(isEnabled ? "" : "Enter the required information first")

            Text(theme.t("SMS · WhatsApp auto-detection enabled", "SMS · WhatsApp ऑटो-डिटेक्शन सक्षम"))
                .scaledFont(size: 12, relativeTo: .caption)
                .foregroundStyle(Color.dimText)
        }
    }

    private var continueLabel: String {
        switch (model.stage, model.status) {
        case (.phone, .sending):    return theme.t("Sending…", "भेज रहे हैं…")
        case (.phone, _):           return theme.t("Continue with Phone", "फ़ोन से जारी रखें")
        case (.otp, .verifying):    return theme.t("Verifying…", "सत्यापित कर रहे हैं…")
        case (.otp, _):             return theme.t("Verify & Continue", "सत्यापित करें और जारी रखें")
        }
    }

    private var continueAccessibilityLabel: String {
        switch model.stage {
        case .phone: return theme.t("Send verification code", "सत्यापन कोड भेजें")
        case .otp:   return theme.t("Verify code and continue", "कोड सत्यापित करें और जारी रखें")
        }
    }
}
