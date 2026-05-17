# GrayMan Android (React Native / Expo)

The Android app lives in `GrayMan-UI/` and mirrors the iOS Swift app feature-for-feature against the same **GrayMan-Backend** API.

## Prerequisites

- Node.js 20+
- Android Studio + emulator or physical device
- GrayMan-Backend running on your LAN (default `http://192.168.1.38:8000`)

## Configure API URL

Edit `src/api/config.js` (or `app.json` → `extra.apiBaseUrl`) to your machine's LAN IP:

```js
export const APIConfig = {
  baseURL: 'http://YOUR_LAN_IP:8000/api/v1',
};
```

Android allows cleartext HTTP via `usesCleartextTraffic: true` in `app.json`.

## Run

```bash
cd GrayMan-UI
npm install
npx expo start --android
```

## Features wired to API

| Feature | Endpoint(s) |
|---------|-------------|
| OTP auth | `POST /auth/otp/send`, `/auth/otp/verify` |
| Profile | `GET/PUT /workers/me` |
| Explore | `GET /explore` |
| Likes / saves / messages | `/likes`, `/saves`, `/messages` |
| Vouches | `POST /vouches` |
| Reel upload | `/reels/upload/init`, `complete`, `abort` |
| AI interview | WebSocket `/interview/ws` |
| Notifications | `GET /notifications`, accept/reject |
| Hires | `POST /hires` |
| Showcase | `GET /workers/{id}/showcase` |

## Auth storage

JWT is stored in **expo-secure-store** (Keychain-equivalent on Android). Worker ID in AsyncStorage.

## Interview audio note

Full duplex 16 kHz PCM streaming (like iOS) needs a native audio module on React Native. The current build connects to the backend WebSocket, shows live transcripts, and receives scores. For production-grade mic streaming, add `react-native-live-audio-stream` or similar.

## OTP in development

The backend prints OTPs to the uvicorn console — there is no SMS gateway yet.
