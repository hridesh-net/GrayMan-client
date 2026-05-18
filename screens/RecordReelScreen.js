import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Animated,
  Linking,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import {
  CameraView,
  useCameraPermissions,
  useMicrophonePermissions,
} from 'expo-camera';
import { LinearGradient } from 'expo-linear-gradient';

import { useTheme } from '../src/AppTheme';
import PressScale from '../src/components/PressScale';
import { uploadReel } from '../src/services/reelUploader';
import { Colors } from '../src/theme';

const MAX_DURATION = 30;

const TIPS = [
  'Your trade & profession',
  'Years of experience',
  "Best projects you've done",
  'Why clients choose you',
];

export default function RecordReelScreen({ goBack, goDone }) {
  const { accent, t } = useTheme();
  const insets = useSafeAreaInsets();

  const [cameraPermission, requestCameraPermission] = useCameraPermissions();
  const [micPermission, requestMicPermission] = useMicrophonePermissions();
  const [permissionsChecked, setPermissionsChecked] = useState(false);
  const [cameraReady, setCameraReady] = useState(false);

  const [phase, setPhase] = useState('idle'); // 'idle' | 'recording' | 'done' | 'failed'
  const [elapsed, setElapsed] = useState(0);
  const [recordingUri, setRecordingUri] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState(null);

  const cameraRef = useRef(null);
  const recordingPromiseRef = useRef(null);
  const timerRef = useRef(null);
  const progressAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    (async () => {
      if (!cameraPermission?.granted) {
        await requestCameraPermission();
      }
      if (!micPermission?.granted) {
        await requestMicPermission();
      }
      setPermissionsChecked(true);
    })();
  }, []);

  const stopRecording = useCallback(() => {
    try {
      cameraRef.current?.stopRecording();
    } catch {
      setUploadError(t('Failed to stop recording', 'रिकॉर्डिंग रोकने में विफल'));
      setPhase('failed');
    }
  }, [t]);

  useEffect(() => {
    if (phase === 'recording') {
      timerRef.current = setInterval(() => {
        setElapsed(prev => {
          const next = prev + 1;
          Animated.timing(progressAnim, {
            toValue: next / MAX_DURATION,
            duration: 1000,
            useNativeDriver: false,
          }).start();
          if (next >= MAX_DURATION) {
            stopRecording();
            return MAX_DURATION;
          }
          return next;
        });
      }, 1000);
    } else {
      clearInterval(timerRef.current);
    }
    return () => clearInterval(timerRef.current);
  }, [phase, progressAnim, stopRecording]);

  const permissionsGranted = cameraPermission?.granted && micPermission?.granted;
  const canRecord = permissionsGranted && cameraReady;

  const startRecording = async () => {
    if (!cameraRef.current || !canRecord || phase === 'recording' || phase === 'done') return;
    setUploadError(null);
    setRecordingUri(null);
    try {
      setElapsed(0);
      progressAnim.setValue(0);
      setPhase('recording');

      const promise = cameraRef.current.recordAsync({
        maxDuration: MAX_DURATION,
      });
      recordPromiseRef.current = promise;

      const video = await promise;
      recordPromiseRef.current = null;
      if (video?.uri) {
        setRecordingUri(video.uri);
        setPhase('done');
      } else {
        throw new Error('No video URI');
      }
    } catch {
      recordPromiseRef.current = null;
      setUploadError(t('Failed to record reel', 'रील रिकॉर्ड करने में विफल'));
      setPhase('failed');
    }
  };

  const handleReRecord = () => {
    recordPromiseRef.current = null;
    setRecordingUri(null);
    setElapsed(0);
    progressAnim.setValue(0);
    setPhase('idle');
    setUploadError(null);
  };

  const handleSubmit = async () => {
    if (!recordingUri || uploading) return;
    setUploading(true);
    setUploadError(null);
    try {
      // Transcript: on-device STT not wired on RN yet (iOS uses ReelTranscriber).
      await uploadReel(recordingUri, null, () => {});
      goDone(recordingUri);
    } catch (err) {
      setUploadError(err.message || t('Upload failed', 'अपलोड विफल'));
    } finally {
      setUploading(false);
    }
  };

  const remaining = MAX_DURATION - elapsed;
  const timerLabel = `0:${String(remaining).padStart(2, '0')}`;

  const statusLabel = () => {
    switch (phase) {
      case 'idle': return t('Ready to record', 'रिकॉर्ड करने के लिए तैयार');
      case 'recording': return t(`${elapsed}s recorded…`, `${elapsed}s रिकॉर्ड हो गया…`);
      case 'done': return t(`${elapsed}s recorded`, `${elapsed}s रिकॉर्ड हो गया`);
      case 'failed': return t('Tap to retry', 'पुनः प्रयास करें');
      default: return '';
    }
  };

  if (!permissionsChecked) {
    return (
      <View style={[styles.root, { alignItems: 'center', justifyContent: 'center' }]}>
        <StatusBar style="light" />
        <ActivityIndicator size="large" color="#fff" />
      </View>
    );
  }

  return (
    <View style={styles.root}>
      <StatusBar style="light" />

      <View style={styles.viewfinder}>
        {permissionsGranted ? (
          <CameraView
            ref={cameraRef}
            style={StyleSheet.absoluteFill}
            facing="front"
            mode="video"
            onCameraReady={() => setCameraReady(true)}
          />
        ) : (
          <View style={[StyleSheet.absoluteFill, { backgroundColor: Colors.shadowGrey, alignItems: 'center', justifyContent: 'center', padding: 24 }]}>
            <Text style={{ fontSize: 32, marginBottom: 10 }}>📷</Text>
            <Text style={{ fontSize: 15, fontWeight: '600', color: '#fff', marginBottom: 4 }}>
              {t('Camera & mic access required', 'कैमरा और माइक की अनुमति चाहिए')}
            </Text>
            <Text style={{ fontSize: 13, color: 'rgba(255,255,255,0.7)', textAlign: 'center' }}>
              {t('Enable them in Settings to record your reel.', 'रील रिकॉर्ड करने के लिए Settings में अनुमति दें।')}
            </Text>
            <PressScale onPress={() => Linking.openSettings()} style={{ marginTop: 20, paddingHorizontal: 20, paddingVertical: 10, backgroundColor: accent, borderRadius: 10 }}>
              <Text style={{ color: '#fff', fontWeight: 'bold' }}>Settings</Text>
            </PressScale>
          </View>
        )}

        <LinearGradient
          colors={['rgba(0,0,0,0.55)', 'rgba(0,0,0,0.18)', 'rgba(0,0,0,0.55)']}
          start={{ x: 0, y: 0 }}
          end={{ x: 0, y: 1 }}
          style={StyleSheet.absoluteFill}
          pointerEvents="none"
        />

        <SafeAreaView edges={['top']} style={styles.viewfinderContent}>
          <View style={styles.topBar}>
            <TouchableOpacity onPress={goBack} style={styles.backBtn} activeOpacity={0.8}>
              <Text style={styles.backArrow}>←</Text>
            </TouchableOpacity>

            <Text style={styles.topBarTitle}>
              {t('Record your reel', 'अपना रील रिकॉर्ड करें')}
            </Text>

            <View style={{ width: 56, alignItems: 'flex-end' }}>
              {phase === 'recording' && (
                <View style={styles.recBadge}>
                  <View style={styles.recDot} />
                  <Text style={styles.recText}>REC</Text>
                </View>
              )}
            </View>
          </View>

          <View style={styles.centerContent}>
            {(phase === 'idle' || phase === 'failed') && (
              <View style={styles.idleState}>
                <View style={styles.avatarCircle}>
                  <Text style={{ fontSize: 44 }}>👤</Text>
                </View>

                <Text style={styles.tipsHeader}>
                  {t('Talk about your:', 'इनके बारे में बताएं:')}
                </Text>

                <View style={styles.tipsList}>
                  {TIPS.map((tip, i) => (
                    <View key={i} style={styles.tipRow}>
                      <View style={[styles.tipDot, { backgroundColor: accent }]} />
                      <Text style={styles.tipText}>{t(tip, tip)}</Text>
                    </View>
                  ))}
                </View>
              </View>
            )}

            {phase === 'recording' && (
              <View style={styles.recordingState}>
                <View style={[styles.avatarCircle, { borderColor: accent, borderWidth: 3 }]}>
                  <Text style={{ fontSize: 44 }}>👤</Text>
                </View>
                <Text style={styles.timerLarge}>{timerLabel}</Text>
                <Text style={styles.timerSub}>
                  {t('seconds remaining · tap to stop', 'सेकंड बचे · रोकने के लिए टैप करें')}
                </Text>
              </View>
            )}

            {phase === 'done' && (
              <View style={styles.doneState}>
                <Text style={styles.doneIcon}>✓</Text>
                <Text style={styles.doneTitle}>{t('Reel recorded!', 'रील रिकॉर्ड हो गया!')}</Text>
                <Text style={styles.doneSub}>
                  {t(`${elapsed}s · ready to submit`, `${elapsed}s · सबमिट के लिए तैयार`)}
                </Text>
              </View>
            )}
          </View>
        </SafeAreaView>
      </View>

      <View style={[styles.controlsSheet, { paddingBottom: Math.max(insets.bottom, 36) }]}>
        <View style={styles.progressBarBg}>
          <Animated.View
            style={[
              styles.progressBarFill,
              {
                backgroundColor: accent,
                width: progressAnim.interpolate({
                  inputRange: [0, 1],
                  outputRange: ['0%', '100%'],
                }),
              },
            ]}
          />
        </View>

        <View style={styles.statusRow}>
          <Text style={styles.statusLabel}>{statusLabel()}</Text>
          <Text style={styles.statusMax}>{t('0:30 max', '0:30 अधिकतम')}</Text>
        </View>

        {uploadError && (
          <Text style={styles.errorText}>{uploadError}</Text>
        )}

        <View style={styles.buttonsWrap}>
          {(phase === 'idle' || phase === 'failed') && (
            <PressScale
              onPress={startRecording}
              disabled={!canRecord}
              style={[
                styles.primaryBtn,
                { backgroundColor: canRecord ? accent : 'rgba(255,255,255,0.4)' },
              ]}
            >
              <Text style={styles.primaryBtnText}>● {t('Start Recording', 'रिकॉर्डिंग शुरू करें')}</Text>
            </PressScale>
          )}

          {phase === 'recording' && (
            <PressScale
              onPress={stopRecording}
              style={[styles.primaryBtn, { backgroundColor: '#E63946' }]}
            >
              <Text style={styles.primaryBtnText}>■ {t('Stop Recording', 'रिकॉर्डिंग रोकें')}</Text>
            </PressScale>
          )}

          {phase === 'done' && (
            <View style={styles.doneActionsRow}>
              <PressScale onPress={handleReRecord} style={styles.reRecordBtn}>
                <Text style={styles.reRecordText}>{t('Re-record', 'फिर से रिकॉर्ड करें')}</Text>
              </PressScale>

              <PressScale
                onPress={handleSubmit}
                disabled={uploading}
                style={[styles.submitBtn, { backgroundColor: accent }, uploading && { opacity: 0.6 }]}
              >
                {uploading ? (
                  <ActivityIndicator color="#fff" size="small" />
                ) : (
                  <Text style={styles.submitBtnText}>{t('Submit Reel', 'रील सबमिट करें')}</Text>
                )}
              </PressScale>
            </View>
          )}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: Colors.shadowGrey,
  },
  viewfinder: {
    flex: 1,
    position: 'relative',
  },
  viewfinderContent: {
    flex: 1,
    justifyContent: 'space-between',
  },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingTop: 12,
  },
  backBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(255,255,255,0.18)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  backArrow: { fontSize: 16, fontWeight: 'bold', color: '#fff' },
  topBarTitle: {
    fontSize: 15,
    fontWeight: 'bold',
    color: 'rgba(255,255,255,0.85)',
  },
  recBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
  },
  recDot: { width: 8, height: 8, borderRadius: 4, backgroundColor: '#E63946' },
  recText: { fontSize: 12, fontWeight: '900', color: '#E63946' },

  centerContent: {
    alignItems: 'center',
    paddingHorizontal: 28,
  },
  avatarCircle: {
    width: 96,
    height: 96,
    borderRadius: 48,
    backgroundColor: 'rgba(255,255,255,0.06)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
    alignItems: 'center',
    justifyContent: 'center',
  },

  idleState: { alignItems: 'center', width: '100%' },
  tipsHeader: { fontSize: 14, fontWeight: '500', color: 'rgba(255,255,255,0.5)', marginTop: 28, marginBottom: 12 },
  tipsList: { width: '100%' },
  tipRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 8, borderBottomWidth: 1, borderBottomColor: 'rgba(255,255,255,0.08)' },
  tipDot: { width: 6, height: 6, borderRadius: 3, marginRight: 10, opacity: 0.7 },
  tipText: { fontSize: 14, color: 'rgba(255,255,255,0.7)' },

  recordingState: { alignItems: 'center' },
  timerLarge: { fontSize: 56, fontWeight: '900', color: '#fff', letterSpacing: -2.5, marginTop: 20 },
  timerSub: { fontSize: 13, color: 'rgba(255,255,255,0.5)', marginTop: 6 },

  doneState: { alignItems: 'center' },
  doneIcon: { fontSize: 48, color: '#fff', marginBottom: 4 },
  doneTitle: { fontSize: 20, fontWeight: '900', color: '#fff', letterSpacing: -0.6 },
  doneSub: { fontSize: 13, color: 'rgba(255,255,255,0.55)', marginTop: 6 },

  controlsSheet: {
    backgroundColor: Colors.canvas,
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    paddingHorizontal: 24,
    paddingTop: 22,
  },
  progressBarBg: {
    height: 5,
    borderRadius: 2.5,
    backgroundColor: 'rgba(39,41,50,0.1)',
    marginBottom: 12,
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    borderRadius: 2.5,
  },
  statusRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 22,
  },
  statusLabel: { fontSize: 13, fontWeight: '500', color: Colors.mutedText },
  statusMax: { fontSize: 13, color: Colors.dimText },

  errorText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#E63946',
    marginBottom: 14,
  },

  buttonsWrap: {
    width: '100%',
  },
  primaryBtn: {
    width: '100%',
    paddingVertical: 17,
    borderRadius: 16,
    alignItems: 'center',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.3,
    shadowRadius: 12,
  },
  primaryBtnText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },

  doneActionsRow: {
    flexDirection: 'row',
    gap: 10,
  },
  reRecordBtn: {
    flex: 1,
    paddingVertical: 16,
    borderRadius: 14,
    borderWidth: 1.5,
    borderColor: 'rgba(39,41,50,0.14)',
    alignItems: 'center',
  },
  reRecordText: {
    fontSize: 15,
    fontWeight: '600',
    color: Colors.shadowGrey,
  },
  submitBtn: {
    flex: 1,
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
    shadowOffset: { width: 0, height: 5 },
    shadowOpacity: 0.3,
    shadowRadius: 10,
  },
  submitBtnText: {
    fontSize: 15,
    fontWeight: 'bold',
    color: '#fff',
  },
});
