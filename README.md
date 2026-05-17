# GrayMan

**Digital identity for gray-collar skilled workers.**

GrayMan helps Tier 2/3 Indian workers — electricians, plumbers, nurses, carpenters and 50+ other trades — build a verified work identity and get discovered by hirers through a peer-trust score called the **Vouch Score**.

---

## What it does

| Feature | Description |
|---|---|
| **Skill Reel** | 30-second intro video shot on-device — the worker's visual portfolio |
| **Vouch Score** | Peer-trust metric (1–100) built from endorsements by past clients and colleagues |
| **Explore Feed** | Vertical swipe feed for hirers — filtered by radius and trade category |
| **AI Voice Interview** | 4-question mock interview with on-device STT + backend scoring (Gemini Flash) |
| **Proof of Work** | Day-by-day photo log compiled into a time-lapse reel |
| **6-language UI** | English, हिंदी, मराठी, తెలుగు, தமிழ், ಕನ್ನಡ — switchable at any screen |

---

## Repo structure

```
GrayMan-UI/
├── ios/GrayMan.swiftpm/      # iOS 26+ production app (SwiftUI, Swift Package)
│   ├── GrayManApp.swift      # Composition root + flat state-machine router
│   ├── VoiceInterview.swift  # SFSpeechRecognizer + backend scoring service
│   ├── Recording.swift       # AVFoundation reel recording service
│   ├── DesignSystem.swift    # scaledFont, FlowLayout, PressScaleStyle, Blobs
│   ├── Theme.swift           # AppTheme (@Observable), AppLanguage, Color(hex:)
│   ├── Worker.swift          # Domain model + Worker.samples
│   └── *.swift               # One file per screen
│
├── screens/                  # React Native screens (Android / cross-platform)
│   ├── OnboardingScreen.js
│   ├── PhoneAuthScreen.js
│   ├── NameEntryScreen.js
│   ├── ChooseRoleScreen.js
│   ├── RecordReelScreen.js
│   ├── ExploreScreen.js
│   ├── ProfileScreen.js
│   ├── VoiceInterviewScreen.js
│   ├── GiveVouchSheet.js
│   ├── ProofOfWorkScreen.js
│   └── SettingsScreen.js
│
├── src/                      # React Native shared foundation
│   ├── AppTheme.js           # Context + useTheme() hook (mirrors iOS AppTheme)
│   ├── theme.js              # Colors, Swatches, Spacing, Radius, Shadow
│   ├── i18n.js               # AppLanguages (6) + makeT() translator
│   ├── workers.js            # WorkerSamples + AllCategories
│   └── components/
│       ├── Blobs.js          # Decorative background circles
│       ├── PressScale.js     # Spring scale on press (mirrors iOS PressScaleStyle)
│       └── VouchScoreRing.js # SVG circular score ring
│
├── App.js                    # RN root — GestureHandler + SafeArea + AppTheme providers
├── app.json                  # Expo config (portrait, edge-to-edge Android, iOS 26+)
└── package.json
```

---

## iOS app

**Requires:** Xcode 16+ or Swift Playgrounds 4+, iOS 26 device or simulator.

Open `ios/GrayMan.swiftpm` directly in Xcode or Swift Playgrounds — there is no `.xcodeproj`.

### Type-check from terminal

```bash
cd ios/GrayMan.swiftpm

xcrun -sdk iphoneos swiftc -typecheck \
  -target arm64-apple-ios26.0 \
  -parse-as-library \
  -strict-concurrency=complete \
  ChooseRoleView.swift ColorPanel.swift DesignSystem.swift ExploreView.swift \
  GiveVouchSheet.swift GrayManApp.swift NameEntryView.swift OnboardingView.swift \
  PhoneAuth.swift PhoneAuthView.swift ProfileView.swift ProofOfWorkView.swift \
  Recording.swift RecordReelView.swift SettingsView.swift Theme.swift \
  VoiceInterview.swift VoiceInterviewView.swift Worker.swift
```

Clean output (no stdout) = success.

### Key architecture decisions

- **Flat state machine** — `GrayManApp` owns a `Screen` enum; every screen gets `goNext`/`goBack` callbacks. No `NavigationStack`.
- **`@Observable` AppTheme** — accent colour + language injected at root via `.environment(theme)`. Any view calling `theme.t()` re-renders on language change.
- **Protocol + mock pattern** — every async feature (`RecordingService`, `VoiceInterviewService`) has a protocol, a real AVFoundation/Speech impl, and a `Mock` impl. `GrayManApp` is the composition root.

---

## Android / React Native app

**Requires:** Node 18+, Expo CLI, Android Studio (for emulator) or physical device.

```bash
npm install
npm run android      # launch on Android emulator / device
npm start            # Expo dev server (scan QR with Expo Go)
```

### Architecture

Mirrors the iOS flat state machine — `App.js` owns screen state and renders the active screen component. No React Navigation library needed.

```
GestureHandlerRootView
  └── SafeAreaProvider
        └── AppThemeProvider      ← Context: accent, language, t(), setLanguage()
              └── AppNavigator    ← switch(screen) state machine
```

Language preference persists via `AsyncStorage` (mirrors iOS `UserDefaults`).

---

## Voice Interviewer — backend contract

The iOS and RN apps both call the same backend endpoint for answer scoring.

```
POST /v1/interview/score
Content-Type: application/json

{ "trade": "Electrician", "question": "...", "answer": "..." }

→ 200 { "confidence": 82, "clarity": 76 }
```

Backend: Python (in progress). Set `BackendConfig.useDummyScores = false` in iOS and update `BackendConfig.baseURL` when the endpoint is live.

---

## Language support

| Language | Code | Status |
|---|---|---|
| English | `en` | Full |
| हिंदी | `hi` | Full |
| मराठी | `mr` | Architecture ready, translations in progress |
| తెలుగు | `te` | Architecture ready, translations in progress |
| தமிழ் | `ta` | Architecture ready, translations in progress |
| ಕನ್ನಡ | `kn` | Architecture ready, translations in progress |

Adding a translation: find a `theme.t("en", "hi")` call and add the labeled param — `theme.t("en", "hi", mr: "मराठी translation")`. All untranslated strings fall back to English.

---

## What's stubbed / not yet real

| Feature | Status |
|---|---|
| Phone / WhatsApp OTP | UI built, routing bypassed |
| Voice interview scoring | Dummy random scores; swap `BackendConfig.useDummyScores = false` when backend is live |
| Reel upload / playback | Recorded to `tmp/` on iOS; not uploaded |
| Worker feed | Static sample data; no API |
| Proof-of-Work photos | UI only; no camera integration on iOS |
| WhatsApp deep link | Hardcoded placeholder number |
| Offline queue | Not implemented |

---

## Contributing

This is a private project. Contact [@hridesh-net](https://github.com/hridesh-net) for access.
