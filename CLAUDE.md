# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

GrayMan is a gray-collar skill worker app for Tier 2/3 Indian workers (electricians, plumbers, nurses, etc.). Workers get a visual identity via a 30s skill reel and a peer-trust "Vouch Score". Hirers discover workers through a vertical swipe feed filtered by radius and trade category.

The repo has two parallel codebases:
- `App.js` — the original React mockup (source of design truth, not shipped)
- `ios/GrayMan.swiftpm/` — the production SwiftUI app (iOS 26+, Swift Package)

All active development is in `ios/GrayMan.swiftpm/`.

## Build and type-check

There is no Xcode project file. The app is a SwiftPM `.swiftpm` package opened directly in Swift Playgrounds or Xcode. To type-check from the terminal:

```bash
cd ios/GrayMan.swiftpm

# Type-check (excludes Package.swift which uses PackageDescription, not app SDK)
xcrun -sdk iphoneos swiftc -typecheck \
  -target arm64-apple-ios26.0 \
  -parse-as-library \
  -strict-concurrency=complete \
  ChooseRoleView.swift ColorPanel.swift DesignSystem.swift ExploreView.swift \
  GiveVouchSheet.swift GrayManApp.swift NameEntryView.swift OnboardingView.swift \
  PhoneAuth.swift PhoneAuthView.swift ProfileView.swift ProofOfWorkView.swift \
  Recording.swift RecordReelView.swift SettingsView.swift Theme.swift \
  VoiceInterviewView.swift Worker.swift 2>&1
```

Clean output (no stdout) = success. There are no unit tests yet.

## Screen routing

Navigation is a flat state machine, not a `NavigationStack`. `GrayManApp.swift` owns a `Screen` enum and a `@ViewBuilder screenView` that switches on it. Every screen receives callbacks (`goNext`, `goBack`) rather than pushing/popping. `GrayManApp` is the only place that transitions between screens.

```
.onboarding → .nameEntry → .chooseRole
                                ├── .recordReel → .profile
                                └── .explore ⇄ .workerProfile
                                       └── .profile
```

Phone auth (`.phoneAuth`) exists in the enum and `PhoneAuthView` is fully built, but routing currently bypasses it: `onboarding.goNext` goes directly to `.nameEntry`. To re-enable auth, change that one closure in `GrayManApp.screenView`.

`previousScreen` tracks where the user came from before `.explore` so the back button returns to the right place (either `.chooseRole` or `.profile`).

## Global state: AppTheme

`AppTheme` is an `@Observable final class` injected at the root via `.environment(theme)`. Every view reads it with `@Environment(AppTheme.self) private var theme`.

It holds two things:
- **Accent colour** (`accent`, `accentHex`, `swatchName`) — changed live via the `ColorPanel` FAB
- **Language** (`language: AppLanguage`) — `.english` or `.hindi`, changed in `SettingsView`

To show a string in the user's chosen language call `theme.t("English", "हिंदी")`. Because `AppTheme` is `@Observable`, any view that calls `t()` automatically re-renders when `language` changes.

The `ColorPanel` overlay is wrapped in `#if DEBUG` in `GrayManApp` so it only appears in debug builds.

## Service + ViewModel pattern

Each feature with async behaviour follows this three-layer layout (both in one file):

```
Protocol          (defines the contract)
Concrete impl     (real AVFoundation / network code)
Mock impl         (for dev/simulator/tests)
@Observable @MainActor ViewModel  (drives the view)
```

Examples:
- `Recording.swift` — `RecordingService` / `AVRecordingService` / `MockRecordingService` / `RecordReelViewModel`
- `PhoneAuth.swift` — `PhoneAuthRepository` / `MockPhoneAuthRepository` / `PhoneAuthViewModel`

`GrayManApp` is the composition root: it instantiates the concrete service and passes it into the view via `init`. To swap implementations (e.g. for a test harness) change only `GrayManApp`.

All ViewModels are `@Observable @MainActor final class`. Timers and async tasks are stored as `Task?` properties and cancelled in `onDisappear`.

## Design system (DesignSystem.swift + Theme.swift)

**Always use these instead of raw values:**

| Need | Use |
|---|---|
| Any text | `.scaledFont(size:, weight:, relativeTo:)` — Dynamic Type-aware via `@ScaledMetric` |
| Brand colours | `Color.shadowGrey`, `.canvas`, `.soft`, `.mutedText`, `.dimText`, `.verifiedBlue` |
| Accent colour | `theme.accent` (changes live) |
| Background blobs | `Blobs(accent: theme.accent, opacity: 0.6)` |
| Button press animation | `.buttonStyle(PressScaleStyle())` or `PressScaleStyle(scale: 0.96)` |
| Wrapping tag chips | `FlowLayout(spacing: 8) { ... }` |
| Verified skill badge | `Image(systemName: "checkmark.seal.fill").symbolRenderingMode(.palette).foregroundStyle(.white, Color.verifiedBlue)` |
| Vouch score ring | `VouchScoreRing(score: worker.vouchScore, size: 64)` — defined in `GiveVouchSheet.swift` |
| Hex colour | `Color(hex: "#ee6c4d")` — extension on `Color` in `Theme.swift` |

`.glassEffect(.regular, in: RoundedRectangle(...))` is used on the profile card, tab bar, and Explore's Professional card. This is iOS 26-only. The entire app is locked to `.preferredColorScheme(.light)` so glass tones stay consistent.

## ProfileView dual mode

`ProfileView` renders both the self-profile dashboard and the read-only view of another worker. The mode is determined by the optional `worker: Worker?` parameter:

- `worker == nil` → own profile: shows Edit/Share/AI Interview/Proof-of-Work CTAs, Settings tab active
- `worker != nil` → other worker: shows back button, populates all display fields from `Worker`, shows Hire/Call/WhatsApp/Vouch actions

All display data is derived via private computed properties (`displayName`, `displayTrade`, `displayVouchScore`, etc.) so the view body never checks `worker` directly.

## Sheets and full-screen covers in ProfileView

ProfileView presents three flows as covers/sheets rather than screen-level navigation:

| State var | Presentation | Content |
|---|---|---|
| `showVoiceInterview` | `.fullScreenCover` | `VoiceInterviewView(trade:)` |
| `showProofOfWork` | `.fullScreenCover` | `ProofOfWorkView()` |
| `showGiveVouch` | `.sheet` | `GiveVouchSheet(worker:)` |
| `showSettings` | `.fullScreenCover` | `SettingsView()` |

`GiveVouchSheet` is also presented from `ExploreView` when the user taps the vouch action button on a worker card.

## Worker data

`Worker.swift` defines the domain model. `Worker.samples` is the only data source — there is no backend yet. `Worker.allCategories` builds the Explore filter list from sample trades at runtime.

`verifiedTagIndices: Set<Int>` marks which skill tags carry a verified badge. `vouchScore` (1–100) is the composite trust metric; `vouched` is the raw endorsement count (currently equal to `vouchScore` in samples).

## What is stubbed / not yet real

| Feature | Status |
|---|---|
| Phone/WhatsApp OTP | Built (`PhoneAuthView` + `PhoneAuthViewModel`) but bypassed in routing |
| Voice interview AI | UI complete; questions/scores are hardcoded stubs — no STT or LLM call |
| Voice note recording in GiveVouchSheet | UI-only; mic button toggles state, no actual audio |
| Proof-of-Work photos | Placeholders; no camera/photo-library integration |
| Worker feed | Static `Worker.samples`; no API, no real video |
| WhatsApp deep link | Opens `wa.me/+919876543210` (hardcoded placeholder) |
| Reel upload / playback | `AVRecordingService` writes to `tmp/`; file is never uploaded or played back |
| Offline queue | Not implemented |

## Planned AI stack for Voice Interviewer (no backend yet)

- **STT**: `SFSpeechRecognizer` with `hi-IN` / `en-IN` locale (free, on-device)
- **LLM**: Gemini 2.0 Flash free tier for scoring and question generation
- **TTS**: `AVSpeechSynthesizer` with `hi-IN` locale for reading questions aloud

## iOS 26 minimum

`Package.swift` targets `.iOS("26.0")`. Do not add any API that requires a higher version. `.glassEffect()` is the main iOS-26-only API in use — it is applied on the tab bar, profile card, and Explore's Professional card.
