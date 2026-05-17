# GrayMan Flutter (Android)

Android client mirroring **`ios/GrayMan.swiftpm/`** — same flat screen router, design tokens, API paths, and feature set. Does not modify the Swift iOS app or the Expo React Native tree at the repo root.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.16+
- Android Studio + emulator or device
- GrayMan backend on your LAN (default `http://192.168.1.38:8000/api/v1`)

## Configure API URL

Edit `lib/core/networking/api_config.dart` or pass at build time:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000/api/v1
```

Cleartext HTTP is allowed in `android/app/src/main/AndroidManifest.xml` for dev LAN testing.

## Run

```bash
cd flutter_app
flutter pub get
flutter run
```

## Architecture (mirrors Swift)

| Swift | Flutter |
|-------|---------|
| `GrayManApp` + `Screen` enum | `lib/app/grayman_app.dart` |
| `AppTheme` / `DesignSystem` | `lib/core/design_system/` |
| `APIClient` / `TokenStore` | `lib/core/networking/` |
| `WorkerService` | `lib/services/worker_service.dart` |
| `Features/*` | `lib/features/*` |

## OTP in development

Backend prints OTPs to the uvicorn console — no SMS gateway yet.
