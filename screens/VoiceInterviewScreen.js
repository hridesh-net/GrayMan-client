import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  Animated,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import * as Speech from 'expo-speech';
import { Audio } from 'expo-av';
import { LinearGradient } from 'expo-linear-gradient';

import { useTheme } from '../src/AppTheme';
import PressScale from '../src/components/PressScale';
import { AppLanguages } from '../src/i18n';
import { Colors, Spacing, Radius, Shadow } from '../src/theme';

// Maps AppLanguages key → TTS locale
const LANG_LOCALE_MAP = {
  en: 'en-IN',
  hi: 'hi-IN',
  mr: 'mr-IN',
  te: 'te-IN',
  ta: 'ta-IN',
  kn: 'kn-IN',
};

const QUESTIONS = [
  'Tell me about your experience. What is the most challenging project you have handled?',
  'A client is unhappy with your work. How do you handle the situation?',
  'Why should someone hire you over another worker with similar skills?',
  'Describe a time you had to learn something new quickly on the job.',
];

export default function VoiceInterviewScreen({ trade, onClose }) {
  const { accent, t } = useTheme();

  // Phase: 'language' | 'intro' | 'questioning' | 'result'
  const [phase, setPhase] = useState('language');
  const [selectedLang, setSelectedLang] = useState(0);
  const [questionIndex, setQuestionIndex] = useState(0);
  const [answeredCount, setAnsweredCount] = useState(0);
  const [isRecording, setIsRecording] = useState(false);
  const [analysing, setAnalysing] = useState(false);
  const [confidenceScore, setConfidenceScore] = useState(0);
  const [clarityScore, setClarityScore] = useState(0);
  // 'speaking' | 'waitingForUser' | 'recording' | 'analysing'
  const [questionState, setQuestionState] = useState('speaking');

  const recordingRef = useRef(null);
  const pulseAnim = useRef(new Animated.Value(1)).current;
  const pulseLoop = useRef(null);
  const ringAnim = useRef(new Animated.Value(1)).current;
  const ringLoop = useRef(null);

  const selectedLangCode = LANG_LOCALE_MAP[AppLanguages[selectedLang]?.key ?? 'en'];

  // Pulse mic button while recording
  useEffect(() => {
    if (questionState === 'recording') {
      pulseLoop.current = Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, { toValue: 1.14, duration: 550, useNativeDriver: true }),
          Animated.timing(pulseAnim, { toValue: 1.0, duration: 550, useNativeDriver: true }),
        ]),
      );
      pulseLoop.current.start();
    } else {
      if (pulseLoop.current) pulseLoop.current.stop();
      Animated.spring(pulseAnim, { toValue: 1, useNativeDriver: true }).start();
    }
  }, [questionState]); // eslint-disable-line react-hooks/exhaustive-deps

  // Pulsing rings on bot avatar while speaking
  useEffect(() => {
    if (questionState === 'speaking') {
      ringLoop.current = Animated.loop(
        Animated.sequence([
          Animated.timing(ringAnim, { toValue: 1.3, duration: 800, useNativeDriver: true }),
          Animated.timing(ringAnim, { toValue: 1.0, duration: 800, useNativeDriver: true }),
        ]),
      );
      ringLoop.current.start();
    } else {
      if (ringLoop.current) ringLoop.current.stop();
      Animated.spring(ringAnim, { toValue: 1, useNativeDriver: true }).start();
    }
  }, [questionState]); // eslint-disable-line react-hooks/exhaustive-deps

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      Speech.stop();
      if (recordingRef.current) {
        recordingRef.current.stopAndUnloadAsync().catch(() => {});
      }
    };
  }, []);

  const speakQuestion = (index) => {
    const question = QUESTIONS[index];
    if (!question) return;
    setQuestionState('speaking');
    Speech.speak(question, {
      language: selectedLangCode,
      onDone: () => setQuestionState('waitingForUser'),
      onError: () => setQuestionState('waitingForUser'),
    });
  };

  const handleStartInterview = () => {
    setPhase('questioning');
    setQuestionIndex(0);
    setAnsweredCount(0);
    speakQuestion(0);
  };

  const startAnswerRecording = async () => {
    try {
      await Audio.setAudioModeAsync({ allowsRecordingIOS: true, playsInSilentModeIOS: true });
      const { recording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY,
      );
      recordingRef.current = recording;
      setQuestionState('recording');
    } catch {
      setQuestionState('waitingForUser');
    }
  };

  const stopAnswerRecording = async () => {
    try {
      if (recordingRef.current) {
        await recordingRef.current.stopAndUnloadAsync();
        recordingRef.current = null;
      }
    } catch {
      // ignore
    }
    setQuestionState('analysing');
    setAnalysing(true);

    // Mock backend scoring
    setTimeout(() => {
      const conf = Math.floor(Math.random() * (92 - 65 + 1)) + 65;
      const clar = Math.floor(Math.random() * (92 - 65 + 1)) + 65;
      const nextAnswered = answeredCount + 1;
      setAnsweredCount(nextAnswered);
      setAnalysing(false);

      if (nextAnswered >= QUESTIONS.length) {
        setConfidenceScore(conf);
        setClarityScore(clar);
        setPhase('result');
      } else {
        const nextIdx = questionIndex + 1;
        setQuestionIndex(nextIdx);
        speakQuestion(nextIdx);
      }
    }, 900);
  };

  const handleMicPress = () => {
    if (questionState === 'waitingForUser') startAnswerRecording();
    else if (questionState === 'recording') stopAnswerRecording();
  };

  const handleTryAgain = () => {
    Speech.stop();
    setPhase('language');
    setSelectedLang(0);
    setQuestionIndex(0);
    setAnsweredCount(0);
    setQuestionState('speaking');
  };

  // --- Language picker phase ---
  if (phase === 'language') {
    const row1 = AppLanguages.slice(0, 3);
    const row2 = AppLanguages.slice(3);
    return (
      <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
        <StatusBar style="dark" />
        <TouchableOpacity onPress={onClose} style={styles.closeBtn} activeOpacity={0.8}>
          <Text style={styles.closeBtnText}>✕</Text>
        </TouchableOpacity>

        <View style={styles.langPhaseContent}>
          <Text style={styles.langHeading}>
            {t('AI Voice Practice', 'AI वॉयस प्रैक्टिस')}
          </Text>
          <Text style={styles.langSubtext}>
            {t('Choose your language to begin the interview', 'इंटरव्यू शुरू करने के लिए भाषा चुनें')}
          </Text>

          <View style={styles.langGrid}>
            <View style={styles.langRow}>
              {row1.map((lang, i) => {
                const sel = selectedLang === i;
                return (
                  <TouchableOpacity
                    key={lang.key}
                    onPress={() => setSelectedLang(i)}
                    style={[styles.langPill, sel && { backgroundColor: accent }]}
                    activeOpacity={0.75}
                  >
                    <Text style={[styles.langPillText, { color: sel ? '#fff' : Colors.shadowGrey }]}>
                      {lang.shortCode}
                    </Text>
                    <Text style={[styles.langPillName, { color: sel ? 'rgba(255,255,255,0.8)' : Colors.mutedText }]}>
                      {lang.displayName}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </View>
            <View style={styles.langRow}>
              {row2.map((lang, i) => {
                const idx = i + 3;
                const sel = selectedLang === idx;
                return (
                  <TouchableOpacity
                    key={lang.key}
                    onPress={() => setSelectedLang(idx)}
                    style={[styles.langPill, sel && { backgroundColor: accent }]}
                    activeOpacity={0.75}
                  >
                    <Text style={[styles.langPillText, { color: sel ? '#fff' : Colors.shadowGrey }]}>
                      {lang.shortCode}
                    </Text>
                    <Text style={[styles.langPillName, { color: sel ? 'rgba(255,255,255,0.8)' : Colors.mutedText }]}>
                      {lang.displayName}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </View>
          </View>
        </View>

        <View style={styles.bottomSection}>
          <PressScale
            onPress={() => setPhase('intro')}
            style={[styles.primaryBtn, { backgroundColor: accent, shadowColor: accent }]}
          >
            <Text style={styles.primaryBtnText}>{t('Continue', 'जारी रखें')}</Text>
          </PressScale>
        </View>
      </SafeAreaView>
    );
  }

  // --- Intro phase ---
  if (phase === 'intro') {
    return (
      <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
        <StatusBar style="dark" />
        <TouchableOpacity onPress={onClose} style={styles.closeBtn} activeOpacity={0.8}>
          <Text style={styles.closeBtnText}>✕</Text>
        </TouchableOpacity>

        <View style={styles.introContent}>
          {/* Bot avatar */}
          <LinearGradient
            colors={[Colors.shadowGrey, accent]}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.botAvatar}
          >
            <Text style={styles.botAvatarIcon}>〜</Text>
          </LinearGradient>

          <Text style={styles.introHeading}>{t('Ready when you are', 'तैयार हैं?')}</Text>
          <Text style={styles.introBody}>
            {t(
              `I'll ask you ${QUESTIONS.length} questions about your work as ${trade ?? 'a skilled worker'}. Speak naturally.`,
              `मैं ${trade ?? 'एक कुशल कामगार'} के रूप में आपके काम के बारे में ${QUESTIONS.length} सवाल पूछूंगा।`,
            )}
          </Text>

          <View style={styles.infoRows}>
            {[
              ['🕐', t('~5 minutes', '~5 मिनट'), t('Short interview', 'छोटा इंटरव्यू')],
              ['🎙', t('Speak clearly', 'स्पष्ट बोलें'), t('Hindi or your language', 'हिंदी या आपकी भाषा')],
              ['📊', t('Instant scores', 'तुरंत स्कोर'), t('Confidence & clarity', 'आत्मविश्वास और स्पष्टता')],
            ].map(([icon, label, sub], i) => (
              <View key={i} style={styles.infoRow}>
                <Text style={styles.infoIcon}>{icon}</Text>
                <View>
                  <Text style={styles.infoLabel}>{label}</Text>
                  <Text style={styles.infoSub}>{sub}</Text>
                </View>
              </View>
            ))}
          </View>
        </View>

        <View style={styles.bottomSection}>
          <PressScale
            onPress={handleStartInterview}
            style={[styles.primaryBtn, { backgroundColor: accent, shadowColor: accent }]}
          >
            <Text style={styles.primaryBtnText}>{t('Start Interview', 'इंटरव्यू शुरू करें')}</Text>
          </PressScale>
        </View>
      </SafeAreaView>
    );
  }

  // --- Questioning phase ---
  if (phase === 'questioning') {
    const micDisabled = questionState === 'speaking' || questionState === 'analysing';
    const micBg = micDisabled
      ? Colors.soft
      : questionState === 'recording'
      ? Colors.recordRed
      : accent;

    return (
      <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
        <StatusBar style="dark" />
        <TouchableOpacity onPress={onClose} style={styles.closeBtn} activeOpacity={0.8}>
          <Text style={styles.closeBtnText}>✕</Text>
        </TouchableOpacity>

        <View style={styles.questioningContent}>
          {/* Progress bar */}
          <View style={styles.progressBar}>
            <View
              style={[
                styles.progressFill,
                { backgroundColor: accent, width: `${(answeredCount / QUESTIONS.length) * 100}%` },
              ]}
            />
          </View>
          <Text style={styles.progressLabel}>
            {t(
              `${answeredCount} of ${QUESTIONS.length} answered`,
              `${answeredCount} / ${QUESTIONS.length} उत्तर दिए`,
            )}
          </Text>

          {/* Bot avatar */}
          <View style={styles.botAvatarWrapper}>
            {questionState === 'speaking' && (
              <Animated.View
                style={[
                  styles.botRing,
                  { borderColor: accent, transform: [{ scale: ringAnim }] },
                ]}
              />
            )}
            <LinearGradient
              colors={[Colors.shadowGrey, accent]}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.botAvatar}
            >
              <Text style={styles.botAvatarIcon}>〜</Text>
            </LinearGradient>
          </View>

          {/* Question bubble */}
          <View style={styles.questionBubble}>
            <Text style={styles.questionText}>{QUESTIONS[questionIndex]}</Text>
          </View>

          {/* Mic button */}
          {analysing ? (
            <View style={styles.analysingRow}>
              <ActivityIndicator color={accent} />
              <Text style={[styles.stateLabel, { marginLeft: 8 }]}>
                {t('Analysing your answer…', 'आपका जवाब विश्लेषण हो रहा है…')}
              </Text>
            </View>
          ) : (
            <>
              <Animated.View style={{ transform: [{ scale: pulseAnim }] }}>
                <TouchableOpacity
                  onPress={handleMicPress}
                  disabled={micDisabled}
                  style={[
                    styles.micBtn,
                    { backgroundColor: micBg },
                    micDisabled && { opacity: 0.4 },
                  ]}
                  activeOpacity={0.85}
                >
                  <Text style={styles.micBtnIcon}>
                    {questionState === 'recording' ? '⏹' : '🎙'}
                  </Text>
                </TouchableOpacity>
              </Animated.View>
              <Text style={styles.stateLabel}>
                {questionState === 'speaking'
                  ? t('Listening to question…', 'सवाल सुन रहे हैं…')
                  : questionState === 'waitingForUser'
                  ? t('Tap mic to answer', 'जवाब देने के लिए माइक टैप करें')
                  : t('Recording…', 'रिकॉर्डिंग हो रही है…')}
              </Text>
            </>
          )}
        </View>
      </SafeAreaView>
    );
  }

  // --- Result phase ---
  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <StatusBar style="dark" />
      <TouchableOpacity onPress={onClose} style={styles.closeBtn} activeOpacity={0.8}>
        <Text style={styles.closeBtnText}>✕</Text>
      </TouchableOpacity>

      <View style={styles.resultContent}>
        <Text style={styles.resultEmoji}>🎉</Text>
        <Text style={styles.resultHeading}>{t('Interview Complete!', 'इंटरव्यू पूरा हुआ!')}</Text>
        <Text style={styles.resultSub}>
          {t('Here are your scores', 'ये हैं आपके स्कोर')}
        </Text>

        <View style={styles.scoreCards}>
          {[
            [t('Confidence', 'आत्मविश्वास'), confidenceScore],
            [t('Clarity', 'स्पष्टता'), clarityScore],
          ].map(([label, score]) => (
            <View key={label} style={styles.scoreCard}>
              <Text style={styles.scoreLabel}>{label}</Text>
              <Text style={[styles.scoreValue, { color: accent }]}>{score}%</Text>
              <View style={styles.scoreBarTrack}>
                <View style={[styles.scoreBarFill, { width: `${score}%`, backgroundColor: accent }]} />
              </View>
            </View>
          ))}
        </View>
      </View>

      <View style={styles.bottomSection}>
        <PressScale onPress={handleTryAgain} style={styles.outlineBtn}>
          <Text style={[styles.outlineBtnText, { color: accent }]}>
            {t('Try Again', 'फिर से कोशिश करें')}
          </Text>
        </PressScale>
        <PressScale
          onPress={onClose}
          style={[styles.primaryBtn, { backgroundColor: accent, shadowColor: accent, marginTop: 10 }]}
        >
          <Text style={styles.primaryBtnText}>{t('Done', 'हो गया')}</Text>
        </PressScale>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.canvas },

  closeBtn: {
    position: 'absolute',
    top: 56,
    left: 16,
    zIndex: 10,
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  closeBtnText: { fontSize: 15, fontWeight: '700', color: Colors.shadowGrey },

  // Language phase
  langPhaseContent: {
    flex: 1,
    paddingTop: 90,
    paddingHorizontal: Spacing.lg,
    alignItems: 'center',
  },
  langHeading: {
    fontSize: 28,
    fontWeight: '800',
    color: Colors.shadowGrey,
    letterSpacing: -0.5,
    marginBottom: 8,
    textAlign: 'center',
  },
  langSubtext: {
    fontSize: 15,
    color: Colors.mutedText,
    textAlign: 'center',
    marginBottom: 36,
    lineHeight: 22,
  },
  langGrid: { width: '100%', gap: 10 },
  langRow: { flexDirection: 'row', gap: 10, justifyContent: 'center' },
  langPill: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: Radius.lg,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
    maxWidth: 110,
  },
  langPillText: { fontSize: 18, fontWeight: '700' },
  langPillName: { fontSize: 11, fontWeight: '500', marginTop: 2 },

  // Intro phase
  introContent: {
    flex: 1,
    paddingTop: 90,
    paddingHorizontal: Spacing.lg,
    alignItems: 'center',
  },
  botAvatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 20,
  },
  botAvatarIcon: { fontSize: 28, color: '#fff' },
  introHeading: {
    fontSize: 26,
    fontWeight: '800',
    color: Colors.shadowGrey,
    letterSpacing: -0.5,
    marginBottom: 10,
    textAlign: 'center',
  },
  introBody: {
    fontSize: 15,
    color: Colors.mutedText,
    textAlign: 'center',
    lineHeight: 22,
    marginBottom: 30,
    maxWidth: 300,
  },
  infoRows: { width: '100%', gap: 14 },
  infoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.soft,
    borderRadius: Radius.md,
    padding: 14,
    gap: 14,
  },
  infoIcon: { fontSize: 22 },
  infoLabel: { fontSize: 14, fontWeight: '700', color: Colors.shadowGrey },
  infoSub: { fontSize: 12, color: Colors.mutedText, marginTop: 1 },

  // Questioning phase
  questioningContent: {
    flex: 1,
    paddingTop: 90,
    paddingHorizontal: Spacing.lg,
    alignItems: 'center',
  },
  progressBar: {
    width: '100%',
    height: 5,
    backgroundColor: Colors.soft,
    borderRadius: 3,
    overflow: 'hidden',
    marginBottom: 6,
  },
  progressFill: { height: '100%', borderRadius: 3 },
  progressLabel: { fontSize: 12, color: Colors.dimText, marginBottom: 24 },
  botAvatarWrapper: { position: 'relative', alignItems: 'center', justifyContent: 'center', marginBottom: 20 },
  botRing: {
    position: 'absolute',
    width: 96,
    height: 96,
    borderRadius: 48,
    borderWidth: 2,
    opacity: 0.4,
  },
  questionBubble: {
    backgroundColor: Colors.soft,
    borderRadius: Radius.lg,
    padding: 18,
    marginBottom: 28,
    width: '100%',
  },
  questionText: {
    fontSize: 16,
    color: Colors.shadowGrey,
    lineHeight: 24,
    fontWeight: '500',
  },
  micBtn: {
    width: 72,
    height: 72,
    borderRadius: 36,
    alignItems: 'center',
    justifyContent: 'center',
    ...Shadow.button,
    shadowColor: '#000',
    marginBottom: 10,
  },
  micBtnIcon: { fontSize: 28 },
  stateLabel: { fontSize: 13, color: Colors.mutedText, fontWeight: '500' },
  analysingRow: { flexDirection: 'row', alignItems: 'center', marginTop: 8 },

  // Result phase
  resultContent: {
    flex: 1,
    paddingTop: 90,
    paddingHorizontal: Spacing.lg,
    alignItems: 'center',
  },
  resultEmoji: { fontSize: 52, marginBottom: 12 },
  resultHeading: {
    fontSize: 26,
    fontWeight: '800',
    color: Colors.shadowGrey,
    marginBottom: 6,
    letterSpacing: -0.5,
  },
  resultSub: { fontSize: 15, color: Colors.mutedText, marginBottom: 32 },
  scoreCards: { width: '100%', gap: 16 },
  scoreCard: {
    backgroundColor: Colors.white,
    borderRadius: Radius.lg,
    padding: 18,
    ...Shadow.card,
  },
  scoreLabel: { fontSize: 14, color: Colors.mutedText, fontWeight: '600', marginBottom: 4 },
  scoreValue: { fontSize: 28, fontWeight: '800', marginBottom: 10 },
  scoreBarTrack: {
    height: 8,
    backgroundColor: Colors.soft,
    borderRadius: 4,
    overflow: 'hidden',
  },
  scoreBarFill: { height: '100%', borderRadius: 4 },

  // Shared bottom section
  bottomSection: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.lg,
  },
  primaryBtn: {
    paddingVertical: 16,
    borderRadius: Radius.lg,
    alignItems: 'center',
    ...Shadow.button,
  },
  primaryBtnText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  outlineBtn: {
    paddingVertical: 16,
    borderRadius: Radius.lg,
    alignItems: 'center',
    borderWidth: 1.5,
    borderColor: 'rgba(39,41,50,0.18)',
    backgroundColor: Colors.soft,
  },
  outlineBtnText: { fontSize: 16, fontWeight: '700' },
});
