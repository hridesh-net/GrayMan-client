import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Animated,
  Linking,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { Audio } from 'expo-av';
import { LinearGradient } from 'expo-linear-gradient';

import { useTheme } from '../src/AppTheme';
import PressScale from '../src/components/PressScale';
import { uploadReel } from '../src/services/reelUploader';
import { Colors, Spacing, Radius, Shadow } from '../src/theme';

const MAX_DURATION = 30;

const TIPS = [
  'Your trade & profession',
  'Years of experience',
  'Best projects you've done',
  'Why clients choose you',
];

export default function RecordReelScreen({ goBack, goDone }) {
  const { accent, t } = useTheme();

  const [cameraPermission, requestCameraPermission] = useCameraPermissions();
  const [audioGranted, setAudioGranted] = useState(false);
  const [permissionsChecked, setPermissionsChecked] = useState(false);

  const [phase, setPhase] = useState('idle'); // 'idle' | 'recording' | 'done'
  const [elapsed, setElapsed] = useState(0);
  const [recordingUri, setRecordingUri] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [uploadPct, setUploadPct] = useState(0);

  const recordingRef = useRef(null);
  const timerRef = useRef(null);
  const pulseAnim = useRef(new Animated.Value(1)).current;
  const pulseLoop = useRef(null);

  // --- Permissions ---
  useEffect(() => {
    (async () => {
      const audioStatus = await Audio.requestPermissionsAsync();
      setAudioGranted(audioStatus.status === 'granted');
      if (!cameraPermission?.granted) {
        await requestCameraPermission();
      }
      setPermissionsChecked(true);
    })();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // --- Pulse animation while recording ---
  useEffect(() => {
    if (phase === 'recording') {
      pulseLoop.current = Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, { toValue: 1.12, duration: 600, useNativeDriver: true }),
          Animated.timing(pulseAnim, { toValue: 1.0, duration: 600, useNativeDriver: true }),
        ]),
      );
      pulseLoop.current.start();
    } else {
      if (pulseLoop.current) pulseLoop.current.stop();
      Animated.spring(pulseAnim, { toValue: 1, useNativeDriver: true }).start();
    }
  }, [phase]); // eslint-disable-line react-hooks/exhaustive-deps

  // --- Timer ---
  useEffect(() => {
    if (phase === 'recording') {
      timerRef.current = setInterval(() => {
        setElapsed(prev => {
          if (prev + 1 >= MAX_DURATION) {
            stopRecording();
            return MAX_DURATION;
          }
          return prev + 1;
        });
      }, 1000);
    } else {
      clearInterval(timerRef.current);
    }
    return () => clearInterval(timerRef.current);
  }, [phase]); // eslint-disable-line react-hooks/exhaustive-deps

  const permissionsGranted = cameraPermission?.granted && audioGranted;

  const startRecording = async () => {
    try {
      await Audio.setAudioModeAsync({ allowsRecordingIOS: true, playsInSilentModeIOS: true });
      const { recording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY,
      );
      recordingRef.current = recording;
      setElapsed(0);
      setPhase('recording');
    } catch (err) {
      console.warn('Failed to start recording', err);
    }
  };

  const stopRecording = async () => {
    try {
      if (recordingRef.current) {
        await recordingRef.current.stopAndUnloadAsync();
        const uri = recordingRef.current.getURI();
        setRecordingUri(uri);
        recordingRef.current = null;
      }
      setPhase('done');
    } catch (err) {
      console.warn('Failed to stop recording', err);
      setPhase('done');
    }
  };

  const handleRecordButton = () => {
    if (phase === 'idle') startRecording();
    else if (phase === 'recording') stopRecording();
  };

  const handleReRecord = () => {
    setRecordingUri(null);
    setElapsed(0);
    setPhase('idle');
    setUploadPct(0);
  };

  const handleSubmit = async () => {
    if (!recordingUri || uploading) return;
    setUploading(true);
    try {
      await uploadReel(recordingUri, null, setUploadPct);
      goDone();
    } catch (err) {
      console.warn('Reel upload failed', err);
      alert(err.message || 'Upload failed');
    } finally {
      setUploading(false);
    }
  };

  const remaining = MAX_DURATION - elapsed;
  const timerLabel = `0:${String(remaining).padStart(2, '0')}`;

  // --- Render: permissions not yet checked ---
  if (!permissionsChecked) {
    return (
      <SafeAreaView style={styles.root}>
        <StatusBar style="dark" />
        <ActivityIndicator size="large" color={accent} style={styles.centred} />
      </SafeAreaView>
    );
  }

  // --- Render: permissions denied ---
  if (!permissionsGranted) {
    return (
      <SafeAreaView style={styles.root}>
        <StatusBar style="dark" />
        <View style={styles.centred}>
          <Text style={styles.permDeniedIcon}>🎙</Text>
          <Text style={styles.permDeniedTitle}>
            {t('Camera & mic access required', 'कैमरा और माइक की अनुमति चाहिए')}
          </Text>
          <Text style={styles.permDeniedBody}>
            {t(
              'Allow camera and microphone access to record your skill reel.',
              'अपना स्किल रील रिकॉर्ड करने के लिए कैमरा और माइक की अनुमति दें।',
            )}
          </Text>
          <PressScale
            onPress={() => Linking.openSettings()}
            style={[styles.settingsBtn, { backgroundColor: accent }]}
          >
            <Text style={styles.settingsBtnText}>{t('Open Settings', 'सेटिंग्स खोलें')}</Text>
          </PressScale>
        </View>
      </SafeAreaView>
    );
  }

  // --- Main render ---
  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <StatusBar style="light" />

      {/* Camera preview */}
      <View style={styles.cameraWrapper}>
        <CameraView style={StyleSheet.absoluteFill} facing="front" />

        {/* Top bar: close button */}
        <TouchableOpacity onPress={goBack} style={styles.closeBtn} activeOpacity={0.8}>
          <Text style={styles.closeBtnText}>✕</Text>
        </TouchableOpacity>

        {/* Recording HUD */}
        {phase === 'recording' && (
          <View style={styles.recHud}>
            <View style={styles.recBadge}>
              <View style={styles.recDot} />
              <Text style={styles.recText}>REC</Text>
            </View>
            <Text style={styles.timerText}>{timerLabel}</Text>
          </View>
        )}

        {/* Idle tips overlay */}
        {phase === 'idle' && (
          <View style={styles.tipsOverlay}>
            <LinearGradient
              colors={['transparent', 'rgba(0,0,0,0.72)']}
              style={styles.tipsGradient}
            >
              <Text style={styles.tipsLabel}>{t('Talk about your:', 'इनके बारे में बताएं:')}</Text>
              {TIPS.map((tip, i) => (
                <Text key={i} style={styles.tipBullet}>
                  {'• '}{t(tip, tip)}
                </Text>
              ))}
            </LinearGradient>
          </View>
        )}

        {/* Done overlay */}
        {phase === 'done' && (
          <View style={styles.doneOverlay}>
            <LinearGradient
              colors={['transparent', 'rgba(0,0,0,0.80)']}
              style={styles.doneGradient}
            >
              <Text style={styles.doneCheckmark}>✓</Text>
              <Text style={styles.doneText}>
                {t(`Reel recorded! ${elapsed}s`, `रील रिकॉर्ड हो गई! ${elapsed} सेकंड`)}
              </Text>
            </LinearGradient>
          </View>
        )}
      </View>

      {/* Bottom controls */}
      <View style={styles.bottomControls}>
        {phase !== 'done' ? (
          <View style={styles.recordRow}>
            <Animated.View style={{ transform: [{ scale: pulseAnim }] }}>
              <TouchableOpacity
                onPress={handleRecordButton}
                style={[
                  styles.recordBtn,
                  phase === 'idle' && { backgroundColor: accent },
                  phase === 'recording' && { backgroundColor: Colors.recordRed },
                ]}
                activeOpacity={0.85}
              >
                <Text style={styles.recordBtnIcon}>
                  {phase === 'idle' ? '🎙' : '⏹'}
                </Text>
              </TouchableOpacity>
            </Animated.View>
            <Text style={styles.recordHint}>
              {phase === 'idle'
                ? t('Tap to record', 'रिकॉर्ड करने के लिए टैप करें')
                : t('Tap to stop', 'रोकने के लिए टैप करें')}
            </Text>
          </View>
        ) : (
          <View style={styles.doneActions}>
            <PressScale onPress={handleReRecord} style={styles.reRecordBtn}>
              <Text style={[styles.reRecordText, { color: accent }]}>
                {t('Re-record', 'फिर से रिकॉर्ड करें')}
              </Text>
            </PressScale>
            <PressScale
              onPress={handleSubmit}
              disabled={uploading}
              style={[styles.submitBtn, { backgroundColor: accent, shadowColor: accent }, uploading && { opacity: 0.6 }]}
            >
              {uploading ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <Text style={styles.submitBtnText}>
                  {uploadPct > 0 ? `${uploadPct}%` : t('Submit Reel', 'रील सबमिट करें')}
                </Text>
              )}
            </PressScale>
          </View>
        )}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#000',
  },
  centred: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 32,
  },

  // Permissions denied
  permDeniedIcon: { fontSize: 48, marginBottom: 16 },
  permDeniedTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: Colors.shadowGrey,
    textAlign: 'center',
    marginBottom: 10,
  },
  permDeniedBody: {
    fontSize: 15,
    color: Colors.mutedText,
    textAlign: 'center',
    lineHeight: 22,
    marginBottom: 28,
  },
  settingsBtn: {
    paddingVertical: 14,
    paddingHorizontal: 32,
    borderRadius: Radius.lg,
    ...Shadow.button,
  },
  settingsBtnText: { color: '#fff', fontSize: 15, fontWeight: '700' },

  // Camera
  cameraWrapper: {
    flex: 1,
    borderRadius: Radius.xl,
    overflow: 'hidden',
    margin: Spacing.md,
  },
  closeBtn: {
    position: 'absolute',
    top: 14,
    left: 14,
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(0,0,0,0.45)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  closeBtnText: { color: '#fff', fontSize: 16, fontWeight: '700' },

  // REC HUD
  recHud: {
    position: 'absolute',
    top: 14,
    right: 14,
    alignItems: 'flex-end',
    gap: 4,
  },
  recBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.recordRed,
    borderRadius: 8,
    paddingHorizontal: 8,
    paddingVertical: 3,
    gap: 5,
  },
  recDot: { width: 7, height: 7, borderRadius: 4, backgroundColor: '#fff' },
  recText: { color: '#fff', fontSize: 12, fontWeight: '800', letterSpacing: 1 },
  timerText: {
    color: '#fff',
    fontSize: 22,
    fontWeight: '700',
    textShadowColor: 'rgba(0,0,0,0.5)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 4,
  },

  // Tips
  tipsOverlay: { position: 'absolute', bottom: 0, left: 0, right: 0 },
  tipsGradient: { paddingTop: 48, paddingBottom: 20, paddingHorizontal: 20 },
  tipsLabel: {
    color: 'rgba(255,255,255,0.75)',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 0.5,
    marginBottom: 6,
    textTransform: 'uppercase',
  },
  tipBullet: { color: '#fff', fontSize: 15, fontWeight: '500', lineHeight: 24 },

  // Done overlay
  doneOverlay: { position: 'absolute', inset: 0 },
  doneGradient: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'flex-end',
    paddingBottom: 28,
  },
  doneCheckmark: { fontSize: 52, color: '#4ade80', marginBottom: 8 },
  doneText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '700',
    textShadowColor: 'rgba(0,0,0,0.5)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 4,
  },

  // Bottom controls
  bottomControls: {
    paddingHorizontal: Spacing.lg,
    paddingVertical: 20,
    alignItems: 'center',
  },
  recordRow: { alignItems: 'center', gap: 10 },
  recordBtn: {
    width: 72,
    height: 72,
    borderRadius: 36,
    alignItems: 'center',
    justifyContent: 'center',
    ...Shadow.button,
    shadowColor: '#000',
  },
  recordBtnIcon: { fontSize: 28 },
  recordHint: {
    color: Colors.dimText,
    fontSize: 13,
    fontWeight: '500',
    marginTop: 6,
  },

  // Done actions
  doneActions: {
    flexDirection: 'row',
    gap: 12,
    width: '100%',
  },
  reRecordBtn: {
    flex: 1,
    paddingVertical: 15,
    borderRadius: Radius.lg,
    alignItems: 'center',
    borderWidth: 1.5,
    borderColor: 'rgba(39,41,50,0.18)',
    backgroundColor: Colors.soft,
  },
  reRecordText: { fontSize: 15, fontWeight: '700' },
  submitBtn: {
    flex: 2,
    paddingVertical: 15,
    borderRadius: Radius.lg,
    alignItems: 'center',
    ...Shadow.button,
  },
  submitBtnText: { color: '#fff', fontSize: 15, fontWeight: '700' },
});
