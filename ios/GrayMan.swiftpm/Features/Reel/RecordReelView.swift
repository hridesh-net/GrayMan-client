import SwiftUI
import AVFoundation

// SRecord — 30s introductory reel recording.
// On a real iPhone: shows live front-camera preview and writes the captured
// video to a temp .mov file via AVCaptureMovieFileOutput.
// On the iOS Simulator: no camera, so the preview is a dark canvas and the
// timer / button flow still works for design review.

struct RecordReelView: View {
    @Environment(AppTheme.self) private var theme
    let goBack: () -> Void
    let goDone: (URL?) -> Void

    @State private var model: RecordReelViewModel

    private var tips: [String] {
        [
            theme.t("Your trade & profession", "आपका ट्रेड और पेशा"),
            theme.t("Years of experience", "अनुभव के साल"),
            theme.t("Best projects you've done", "आपके बेहतरीन प्रोजेक्ट"),
            theme.t("Why clients choose you", "ग्राहक आपको क्यों चुनते हैं"),
        ]
    }

    init(model: RecordReelViewModel,
         goBack: @escaping () -> Void,
         goDone: @escaping (URL?) -> Void) {
        _model = State(wrappedValue: model)
        self.goBack = goBack
        self.goDone = goDone
    }

    var body: some View {
        ZStack {
            Color.shadowGrey.ignoresSafeArea()

            VStack(spacing: 0) {
                viewfinder
                controlsSheet
            }
        }
        .task { await model.onAppear() }
        .onDisappear { Task { await model.onDisappear() } }
        .voiceGuide(
            en: "Now we need a thirty second video. Tell us your trade, how many years " +
                "of experience you have, and show your best work. Speak clearly. " +
                "When you are ready, tap the red record button. Tap Submit when done.",
            hi: "अब आपको तीस सेकंड का एक वीडियो बनाना है। बताइए आप क्या काम करते हैं, " +
                "कितने साल का अनुभव है, और अपना सबसे अच्छा काम दिखाइए। साफ़ बोलिए। " +
                "तैयार हों तो लाल बटन दबाइए। काम पूरा हो जाए तो सबमिट पर टैप कीजिए।"
        )
    }

    // MARK: - Top viewfinder

    private var viewfinder: some View {
        ZStack(alignment: .top) {
            Group {
                if model.permission == .granted {
                    CameraPreview(session: model.service.session)
                        .accessibilityLabel("Live camera preview")
                } else {
                    Color.shadowGrey
                        .overlay(permissionMessage)
                }
            }
            .ignoresSafeArea(edges: [.top, .horizontal])

            LinearGradient(
                colors: [.black.opacity(0.55), .black.opacity(0.18), .black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: [.top, .horizontal])
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                topBar
                Spacer()
                centerContent
                Spacer()
            }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var permissionMessage: some View {
        if model.permission == .denied {
            VStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityHidden(true)
                Text(theme.t("Camera & mic access required", "कैमरा और माइक की अनुमति चाहिए"))
                    .scaledFont(size: 15, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(.white)
                Text(theme.t("Enable them in Settings to record your reel.", "रील रिकॉर्ड करने के लिए Settings में अनुमति दें।"))
                    .scaledFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .accessibilityElement(children: .combine)
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: goBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.18)))
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(theme.t("Back", "वापस"))

            Spacer()

            Text(theme.t("Record your reel", "अपना रील रिकॉर्ड करें"))
                .scaledFont(size: 15, weight: .bold, relativeTo: .subheadline)
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            Group {
                if model.phase == .recording {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(hex: "#E63946"))
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text("REC")
                            .scaledFont(size: 12, weight: .heavy, relativeTo: .caption2)
                            .foregroundStyle(Color(hex: "#E63946"))
                    }
                    .accessibilityLabel(theme.t("Recording in progress", "रिकॉर्डिंग जारी है"))
                } else {
                    Color.clear
                }
            }
            .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var centerContent: some View {
        switch model.phase {
        case .idle, .failed:
            VStack(spacing: 0) {
                avatarCircle
                    .padding(.bottom, 28)

                Text(theme.t("Talk about your:", "इनके बारे में बताएं:"))
                    .scaledFont(size: 14, weight: .medium, relativeTo: .footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 12)

                VStack(spacing: 0) {
                    ForEach(tips, id: \.self) { t in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(theme.accent.opacity(0.70))
                                .frame(width: 6, height: 6)
                                .accessibilityHidden(true)
                            Text(t)
                                .scaledFont(size: 14, relativeTo: .body)
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(.white.opacity(0.08))
                                .frame(height: 1)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tips: " + tips.joined(separator: ", "))
            }
            .padding(.horizontal, 28)

        case .recording:
            VStack(spacing: 6) {
                avatarCircle.padding(.bottom, 20)
                Text(fmt(model.remaining))
                    .scaledFont(size: 56, weight: .heavy, relativeTo: .largeTitle)
                    .foregroundStyle(.white)
                    .tracking(-2.5)
                    .accessibilityLabel("\(model.remaining) seconds remaining")
                Text(theme.t("seconds remaining · tap to stop", "सेकंड बचे · रोकने के लिए टैप करें"))
                    .scaledFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .accessibilityHidden(true)
            }

        case .done:
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)
                    .accessibilityHidden(true)
                Text(theme.t("Reel recorded!", "रील रिकॉर्ड हो गया!"))
                    .scaledFont(size: 20, weight: .heavy, relativeTo: .title2)
                    .foregroundStyle(.white)
                    .tracking(-0.6)
                Text(theme.t("\(model.elapsed)s · ready to submit", "\(model.elapsed)s · सबमिट के लिए तैयार"))
                    .scaledFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var avatarCircle: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.06))
                .overlay(Circle().stroke(.white.opacity(0.10), lineWidth: 1))
                .frame(width: 96, height: 96)
            Image(systemName: "person.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.7))
            if model.phase == .recording {
                Circle()
                    .stroke(theme.accent.opacity(0.75), lineWidth: 3)
                    .frame(width: 104, height: 104)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Bottom controls sheet

    private var controlsSheet: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.shadowGrey.opacity(0.10))
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: geo.size.width * model.progress)
                        .animation(.linear(duration: 0.8), value: model.elapsed)
                }
            }
            .frame(height: 5)
            .padding(.bottom, 12)
            .accessibilityLabel("Progress")
            .accessibilityValue("\(Int(model.progress * 100)) percent")

            HStack {
                Text(statusLabel)
                    .scaledFont(size: 13, weight: .medium, relativeTo: .footnote)
                    .foregroundStyle(Color.mutedText)
                Spacer()
                Text(theme.t("0:30 max", "0:30 अधिकतम"))
                    .scaledFont(size: 13, relativeTo: .footnote)
                    .foregroundStyle(Color.dimText)
            }
            .padding(.bottom, 22)

            if let error = errorMessage {
                Text(error)
                    .scaledFont(size: 13, weight: .semibold, relativeTo: .footnote)
                    .foregroundStyle(Color(hex: "#E63946"))
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            buttons
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 36)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 28, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 28,
                style: .continuous
            )
            .fill(Color.canvas)
        )
    }

    @ViewBuilder
    private var buttons: some View {
        switch model.phase {
        case .idle, .failed:
            Button {
                Task { await model.startRecording(lang: theme.language) }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "circle.fill").font(.system(size: 14))
                    Text(theme.t("Start Recording", "रिकॉर्डिंग शुरू करें"))
                        .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(model.permission == .granted ? theme.accent : Color.dimText.opacity(0.4))
                )
                .shadow(color: theme.accent.opacity(0.36), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PressScaleStyle())
            .disabled(model.permission != .granted)
            .accessibilityLabel(theme.t("Start recording", "रिकॉर्डिंग शुरू करें"))
            .accessibilityHint(model.permission == .granted ? "" : "Camera access required")

        case .recording:
            Button {
                Task { await model.stopRecording() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "stop.fill").font(.system(size: 14))
                    Text(theme.t("Stop Recording", "रिकॉर्डिंग रोकें"))
                        .scaledFont(size: 16, weight: .bold, relativeTo: .headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: "#E63946"))
                )
                .shadow(color: Color(hex: "#E63946").opacity(0.36),
                        radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel(theme.t("Stop recording", "रिकॉर्डिंग रोकें"))

        case .done:
            HStack(spacing: 10) {
                Button {
                    model.reset()
                } label: {
                    Text(theme.t("Re-record", "फिर से रिकॉर्ड करें"))
                        .scaledFont(size: 15, weight: .semibold, relativeTo: .body)
                        .foregroundStyle(Color.shadowGrey)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.shadowGrey.opacity(0.14), lineWidth: 1.5)
                        )
                }
                .buttonStyle(PressScaleStyle(scale: 0.96))
                .accessibilityLabel(theme.t("Re-record reel", "रील फिर से रिकॉर्ड करें"))

                // Submit is now instant — submitReel hands the raw
                // recording to OfflineReelQueue and immediately calls
                // goDone. No spinner, no disabled state, no blocked
                // button. Compression + upload happen in the
                // background; ProfileView shows progress.
                Button {
                    submitReel()
                } label: {
                    Text(theme.t("Submit Reel", "रील सबमिट करें"))
                        .scaledFont(size: 15, weight: .bold, relativeTo: .body)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(theme.accent)
                        )
                        .shadow(color: theme.accent.opacity(0.34),
                                radius: 10, x: 0, y: 5)
                }
                .buttonStyle(PressScaleStyle(scale: 0.97))
                .accessibilityLabel(theme.t("Submit reel", "रील सबमिट करें"))
            }
        }
    }

    // MARK: - Derived

    private var statusLabel: String {
        switch model.phase {
        case .idle:      return "Ready to record"
        case .recording: return "\(model.elapsed)s recorded…"
        case .done:      return "\(model.elapsed)s recorded"
        case .failed:    return "Tap to retry"
        }
    }

    private var errorMessage: String? {
        // No more in-flight upload error to surface here — submit is
        // non-blocking and any post-submit error surfaces in the
        // OfflineReelQueue banner on the Profile screen.
        if case .failed(let msg) = model.phase { return msg }
        return nil
    }

    private func submitReel() {
        // No await, no spinner, no blocked button. We hand the raw
        // recording to OfflineReelQueue (a fast file-move into App
        // Support) and immediately navigate to Profile. Compression
        // and upload happen entirely in the background; ProfileView
        // surfaces progress via the OfflineReelQueue banner.
        if let recorded = model.recordedURL,
           FileManager.default.fileExists(atPath: recorded.path) {
            OfflineReelQueue.shared.enqueueRawRecording(
                fileURL: recorded,
                transcript: model.transcript,
            )
        }
        goDone(model.recordedURL)
    }

    private func fmt(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
