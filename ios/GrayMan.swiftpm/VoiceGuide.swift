@preconcurrency import AVFoundation
import SwiftUI

// MARK: - Voice guidance (TTS)
//
// On a gray-collar platform a sizeable share of users can't read fluently
// in any language we ship strings for. Voice guidance is the bridge: every
// major screen has a localized script that gets read aloud, in Hindi or
// English, on first appear (when enabled in Settings) and on-demand via a
// speaker icon.
//
// Implementation note: AVSpeechSynthesizer with `hi-IN` reads Devanagari
// text naturally. Hinglish (Latin script) words inside a `hi-IN` voice
// sound mangled, so all the Hindi scripts use Devanagari. The same screen
// also has an English script for users on the `en` locale.
//
// Voice guidance is OFF by default during onboarding (we don't want to
// surprise the user with audio); turn-on is a single toggle in Settings.

@MainActor
@Observable
final class VoiceGuide {
    static let shared = VoiceGuide()

    private let synth = AVSpeechSynthesizer()
    private(set) var isSpeaking: Bool = false

    private let enabledKey = "sthapna.voice_guide.enabled"

    /// User preference (persisted). Default false — opt-in.
    var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            if !newValue { stop() }
        }
    }

    /// Speak the given localized script. Tries the Gemini Live narrator
    /// first (higher Hinglish quality), transparently falls back to
    /// on-device AVSpeechSynthesizer on any error so the user always
    /// hears guidance — offline, no key, or WS failure are all handled.
    /// Cancels anything in flight first so a screen change doesn't leave
    /// two voices overlapping.
    func speak(_ text: String, lang: AppLanguage) {
        guard !text.isEmpty else { return }
        stop()
        isSpeaking = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await GeminiLiveVoiceGuide.shared.speak(text, lang: lang)
                // Stayed Gemini-driven through to drain.
                self.isSpeaking = false
            } catch is CancellationError {
                // Caller called stop(); isSpeaking is already cleared.
                self.isSpeaking = false
            } catch {
                // Gemini path unavailable — fall back to AVSpeechSynthesizer.
                self.speakWithSystemSynth(text, lang: lang)
            }
        }
    }

    /// Auto-play helper for "fire on screen appear if enabled in settings"
    /// — does nothing when voice guidance is disabled.
    func autoPlay(_ text: String, lang: AppLanguage) {
        guard enabled else { return }
        speak(text, lang: lang)
    }

    func stop() {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        Task { @MainActor in
            await GeminiLiveVoiceGuide.shared.stop()
        }
        isSpeaking = false
    }

    /// AVSpeechSynthesizer fallback path. Used when Gemini Live is
    /// unavailable (offline, no key, transient error).
    private func speakWithSystemSynth(_ text: String, lang: AppLanguage) {
        let utter = AVSpeechUtterance(string: text)
        utter.voice = AVSpeechSynthesisVoice(language: lang.ttsLocale)
        utter.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utter.pitchMultiplier = 1.0
        utter.volume = 1.0
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio,
                                                         options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        isSpeaking = true
        synth.speak(utter)
    }
}

extension AppLanguage {
    /// Best TTS voice locale per language. `hi-IN` for Hindi gives Devanagari
    /// the natural Indian accent; `en-IN` keeps English pronunciations
    /// locally-familiar (rupee, etc.) for our target user base.
    var ttsLocale: String {
        switch self {
        case .hindi:   return "hi-IN"
        case .marathi: return "mr-IN"
        case .telugu:  return "te-IN"
        case .tamil:   return "ta-IN"
        case .kannada: return "kn-IN"
        case .english: return "en-IN"
        }
    }
}


// MARK: - SwiftUI helpers

/// Small speaker icon that, on tap, reads the supplied script aloud.
/// Drop into any toolbar / nav row so the user can replay instructions
/// anytime. Visual state changes when speech is in flight so the user
/// gets feedback that the audio is actually playing.
struct VoiceGuideButton: View {
    @Environment(AppTheme.self) private var theme

    let englishScript: String
    let hindiScript: String

    var body: some View {
        Button {
            let script = theme.language == .hindi ? hindiScript : englishScript
            VoiceGuide.shared.speak(script, lang: theme.language)
        } label: {
            Image(systemName: VoiceGuide.shared.isSpeaking
                  ? "speaker.wave.3.fill"
                  : "speaker.wave.2")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VoiceGuide.shared.isSpeaking
                                 ? theme.accent : Color.shadowGrey)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(VoiceGuide.shared.isSpeaking
                              ? theme.accent.opacity(0.12) : Color.soft)
                )
                .overlay(
                    Circle()
                        .stroke(VoiceGuide.shared.isSpeaking
                                ? theme.accent.opacity(0.30) : .clear,
                                lineWidth: 1.5)
                )
        }
        .accessibilityLabel("Play voice guidance")
    }
}


// MARK: - View modifier — auto-play on appear

extension View {
    /// Call as `.voiceGuide(en: "...", hi: "...")` on the root of a screen
    /// to auto-play the script when the view first appears (and only when
    /// the user has enabled voice guidance in Settings).
    func voiceGuide(en: String, hi: String) -> some View {
        modifier(VoiceGuideAutoPlay(englishScript: en, hindiScript: hi))
    }
}

private struct VoiceGuideAutoPlay: ViewModifier {
    @Environment(AppTheme.self) private var theme
    let englishScript: String
    let hindiScript: String

    func body(content: Content) -> some View {
        content
            .onAppear { replay() }
            // Re-narrate on the current screen the moment the user picks
            // a different language (e.g. from the language pills on the
            // welcome screen, or from Settings). Without this, switching
            // mid-screen would only take effect on the NEXT screen.
            .onChange(of: theme.language) { _, _ in replay() }
            .onDisappear { VoiceGuide.shared.stop() }
    }

    private func replay() {
        let script = theme.language == .hindi ? hindiScript : englishScript
        VoiceGuide.shared.autoPlay(script, lang: theme.language)
    }
}
