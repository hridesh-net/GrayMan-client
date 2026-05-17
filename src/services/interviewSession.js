/**
 * Backend-mediated Gemini Live interview WebSocket.
 * Mirrors iOS InterviewSession.swift wire protocol.
 */
import AudioModule, {
  RecordingPresets,
  setAudioModeAsync,
  requestRecordingPermissionsAsync,
} from 'expo-audio';
import { wsURL } from '../api/config';

const INPUT_RATE = 16000;
const OUTPUT_RATE = 24000;

export class InterviewSession {
  constructor({ token, lang, trade, duration = 4, roleType, voice }) {
    this.token = token;
    this.lang = lang;
    this.trade = trade;
    this.duration = duration;
    this.roleType = roleType;
    this.voice = voice;
    this.ws = null;
    this.recording = null;
    this.soundQueue = [];
    this.isPlaying = false;
    this.state = 'idle';
    this.onStateChange = null;
    this.onText = null;
    this.onScores = null;
    this.onError = null;
  }

  _setState(s) {
    this.state = s;
    this.onStateChange?.(s);
  }

  connect() {
    const query = { token: this.token, lang: this.lang };
    if (this.trade) query.trade = this.trade;
    if (this.duration) query.duration = String(this.duration);
    if (this.roleType) query.role_type = this.roleType;
    if (this.voice) query.voice = this.voice;

    const url = wsURL('/interview/ws', query);
    this.ws = new WebSocket(url);
    this._setState('connecting');

    this.ws.onopen = () => this._onOpen();
    this.ws.onmessage = (ev) => this._onMessage(ev.data);
    this.ws.onerror = () => {
      this._setState('failed');
      this.onError?.('WebSocket connection failed');
    };
    this.ws.onclose = () => {
      if (this.state !== 'ended') this._setState('ended');
    };
  }

  async _onOpen() {
    try {
      await requestRecordingPermissionsAsync();
      await setAudioModeAsync({
        allowsRecording: true,
        playsInSilentMode: true,
        shouldPlayInBackground: false,
      });
      this._setState('listening');
      // Note: full 16kHz PCM streaming requires a native module on RN.
      // For Android MVP we use expo-audio chunked recording and send base64 blobs.
      this._startChunkedCapture();
    } catch (e) {
      this._setState('failed');
      this.onError?.(e.message);
    }
  }

  async _startChunkedCapture() {
    this.recording = new AudioModule.AudioRecorder(RecordingPresets.HIGH_QUALITY);
    await this.recording.prepareToRecordAsync();
    this.recording.record();
    this._captureInterval = setInterval(async () => {
      if (!this.recording || this.state !== 'listening' && this.state !== 'speaking') return;
      try {
        const uri = this.recording.uri;
        if (!uri) return;
        // Send end marker pattern: client sends periodic audio via file read
        // Production: use react-native-live-audio-stream for true PCM16 16kHz
        const status = this.recording.getStatus();
        if (status.isRecording) {
          // Placeholder: backend VAD still works with less frequent chunks on dev
        }
      } catch { /* ignore */ }
    }, 500);
  }

  _send(obj) {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(obj));
    }
  }

  sendAudioBase64(b64) {
    this._send({ type: 'audio', data: b64 });
  }

  async _onMessage(raw) {
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }

    switch (msg.type) {
      case 'ready':
        this._setState('listening');
        break;
      case 'audio':
        if (msg.data) {
          this._setState('speaking');
          await this._playPCMBase64(msg.data);
        }
        break;
      case 'text':
        if (msg.text) this.onText?.(msg.text);
        break;
      case 'scores':
        this.onScores?.({
          confidence: msg.confidence ?? 0,
          clarity: msg.clarity ?? 0,
          trade_competence: msg.trade_competence ?? 0,
          summary: msg.summary ?? '',
          labels: msg.labels,
        });
        break;
      case 'done':
        this._setState('ended');
        break;
      case 'error':
        this._setState('failed');
        this.onError?.(msg.message || 'Interview error');
        break;
      default:
        break;
    }
  }

  async _playPCMBase64(b64) {
    // expo-audio cannot play raw PCM directly without WAV header wrapping.
    // iOS uses AVAudioEngine; for RN Android use TTS fallback on text frames
    // or integrate react-native-audio-api in a follow-up.
    this._setState('speaking');
    setTimeout(() => {
      if (this.state === 'speaking') this._setState('listening');
    }, 800);
  }

  async stop() {
    clearInterval(this._captureInterval);
    if (this.recording) {
      try {
        await this.recording.stop();
      } catch { /* ignore */ }
      this.recording = null;
    }
    this._send({ type: 'end' });
    this.ws?.close();
    this._setState('ended');
  }
}
