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
import { LinearGradient } from 'expo-linear-gradient';

import { useTheme } from '../src/AppTheme';
import { tpl } from '../src/i18n';
import PressScale from '../src/components/PressScale';
import { InterviewSession } from '../src/services/interviewSession';
import { tokenStore } from '../src/api/tokenStore';
import { Colors, Spacing, Radius, Shadow } from '../src/theme';

const INTERVIEW_LANGS = [
  { key: 'en', label: 'English', sub: 'Clear simple English' },
  { key: 'hi', label: 'हिंदी', sub: 'Hindi' },
  { key: 'hi-en', label: 'Hinglish', sub: 'Hindi + English mix' },
  { key: 'mr', label: 'मराठी', sub: 'Marathi' },
  { key: 'te', label: 'తెలుగు', sub: 'Telugu' },
  { key: 'ta', label: 'தமிழ்', sub: 'Tamil' },
];

export default function VoiceInterviewScreen({ trade, onClose, durationMinutes = 2 }) {
  const { accent, t } = useTheme();
  const [phase, setPhase] = useState('language');
  const [langKey, setLangKey] = useState('en');
  const [state, setState] = useState('idle');
  const [subtitle, setSubtitle] = useState('');
  const [scores, setScores] = useState(null);
  const [error, setError] = useState(null);
  const sessionRef = useRef(null);
  const ringAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    return () => {
      sessionRef.current?.stop();
      Speech.stop();
    };
  }, []);

  useEffect(() => {
    if (state === 'speaking' || state === 'listening') {
      Animated.loop(
        Animated.sequence([
          Animated.timing(ringAnim, { toValue: 1.25, duration: 700, useNativeDriver: true }),
          Animated.timing(ringAnim, { toValue: 1, duration: 700, useNativeDriver: true }),
        ]),
      ).start();
    }
  }, [state, ringAnim]);

  const startInterview = async () => {
    const token = tokenStore.token;
    if (!token) {
      setError(t('Please sign in first', 'पहले साइन इन करें'));
      return;
    }
    setPhase('live');
    setError(null);
    setScores(null);
    setSubtitle('');

    const session = new InterviewSession({
      token,
      lang: langKey,
      trade: typeof trade === 'string' ? trade.split('·')[0].trim() : trade,
      duration: durationMinutes,
    });
    session.onStateChange = setState;
    session.onText = text => {
      setSubtitle(text);
      Speech.speak(text, { language: langKey === 'hi' ? 'hi-IN' : 'en-IN' });
    };
    session.onScores = s => {
      setScores(s);
      setPhase('result');
      session.stop();
    };
    session.onError = msg => setError(msg);
    sessionRef.current = session;
    session.connect();
  };

  const endInterview = async () => {
    await sessionRef.current?.stop();
    if (!scores) setPhase('language');
  };

  if (phase === 'language') {
    return (
      <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
        <StatusBar style="dark" />
        <View style={styles.header}>
          <PressScale onPress={onClose} style={styles.closeBtn}>
            <Text style={styles.closeBtnText}>✕</Text>
          </PressScale>
          <Text style={styles.headerTitle}>{t('AI Mock Interview', 'AI मॉक इंटरव्यू')}</Text>
          <View style={{ width: 36 }} />
        </View>
        <Text style={styles.langHint}>
          {`~${durationMinutes} ${tpl(t, 'min · pick your language', 'मिनट · भाषा चुनें')}`}
        </Text>
        <ScrollView contentContainerStyle={styles.langList}>
          {INTERVIEW_LANGS.map(l => (
            <PressScale
              key={l.key}
              onPress={() => setLangKey(l.key)}
              style={[
                styles.langCard,
                langKey === l.key && { borderColor: accent, borderWidth: 2 },
              ]}
            >
              <Text style={styles.langLabel}>{l.label}</Text>
              <Text style={styles.langSub}>{l.sub}</Text>
            </PressScale>
          ))}
        </ScrollView>
        {error ? <Text style={styles.error}>{error}</Text> : null}
        <PressScale onPress={startInterview} style={[styles.cta, { backgroundColor: accent }]}>
          <Text style={styles.ctaText}>{t('Start Interview', 'इंटरव्यू शुरू करें')}</Text>
        </PressScale>
      </SafeAreaView>
    );
  }

  if (phase === 'result' && scores) {
    const labels = scores.labels || {
      confidence: 'Communication Confidence',
      clarity: 'Persuasion Clarity',
      trade_competence: 'Trade Competence',
    };
    return (
      <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
        <StatusBar style="dark" />
        <View style={styles.resultHeader}>
          <Text style={styles.resultTitle}>{t('Interview Complete', 'इंटरव्यू पूरा')}</Text>
        </View>
        <View style={styles.scoreGrid}>
          {[
            ['confidence', scores.confidence],
            ['clarity', scores.clarity],
            ['trade_competence', scores.trade_competence],
          ].map(([key, val]) => (
            <View key={key} style={[styles.scoreCard, Shadow.card]}>
              <Text style={styles.scoreValue}>{val}</Text>
              <Text style={styles.scoreLabel}>{labels[key] || key}</Text>
            </View>
          ))}
        </View>
        {scores.summary ? (
          <Text style={styles.summary}>{scores.summary}</Text>
        ) : null}
        <PressScale onPress={onClose} style={[styles.cta, { backgroundColor: accent }]}>
          <Text style={styles.ctaText}>{t('Done', 'हो गया')}</Text>
        </PressScale>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <StatusBar style="dark" />
      <View style={styles.liveHeader}>
        <PressScale onPress={endInterview} style={styles.closeBtn}>
          <Text style={styles.closeBtnText}>✕</Text>
        </PressScale>
        <Text style={styles.liveTitle}>
          {state === 'connecting' ? t('Connecting…', 'कनेक्ट हो रहा है…') : t('Live', 'लाइव')}
        </Text>
      </View>

      <View style={styles.avatarArea}>
        <Animated.View style={[styles.ring, { transform: [{ scale: ringAnim }], borderColor: accent }]} />
        <LinearGradient colors={[Colors.shadowGrey, accent]} style={styles.avatar}>
          <Text style={styles.avatarEmoji}>🎙</Text>
        </LinearGradient>
      </View>

      <Text style={styles.subtitle}>{subtitle || t('Speak naturally…', 'स्वाभाविक रूप से बोलें…')}</Text>
      {error ? <Text style={styles.error}>{error}</Text> : null}

      <View style={styles.liveFooter}>
        {state === 'connecting' && <ActivityIndicator color={accent} />}
        <PressScale onPress={endInterview} style={[styles.endBtn, { borderColor: accent }]}>
          <Text style={[styles.endBtnText, { color: accent }]}>{t('End interview', 'इंटरव्यू समाप्त')}</Text>
        </PressScale>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.canvas },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingTop: 8 },
  closeBtn: { width: 36, height: 36, borderRadius: 12, backgroundColor: Colors.soft, alignItems: 'center', justifyContent: 'center' },
  closeBtnText: { fontSize: 16, fontWeight: '700', color: Colors.shadowGrey },
  headerTitle: { fontSize: 18, fontWeight: '800', color: Colors.shadowGrey },
  langHint: { paddingHorizontal: 24, color: Colors.mutedText, marginBottom: 12 },
  langList: { paddingHorizontal: 20, gap: 10, paddingBottom: 16 },
  langCard: { backgroundColor: Colors.white, borderRadius: 14, padding: 16, marginBottom: 8, ...Shadow.card },
  langLabel: { fontSize: 17, fontWeight: '700', color: Colors.shadowGrey },
  langSub: { fontSize: 13, color: Colors.mutedText, marginTop: 2 },
  cta: { marginHorizontal: 24, marginBottom: 24, paddingVertical: 16, borderRadius: 16, alignItems: 'center', ...Shadow.button },
  ctaText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  error: { color: '#DC2626', textAlign: 'center', margin: 12 },
  liveHeader: { flexDirection: 'row', alignItems: 'center', padding: 20, gap: 12 },
  liveTitle: { fontSize: 16, fontWeight: '700', color: Colors.shadowGrey },
  avatarArea: { alignItems: 'center', justifyContent: 'center', height: 200 },
  ring: { position: 'absolute', width: 140, height: 140, borderRadius: 70, borderWidth: 2 },
  avatar: { width: 100, height: 100, borderRadius: 50, alignItems: 'center', justifyContent: 'center' },
  avatarEmoji: { fontSize: 40 },
  subtitle: { paddingHorizontal: 24, fontSize: 16, color: Colors.mutedText, textAlign: 'center', minHeight: 60 },
  liveFooter: { flex: 1, justifyContent: 'flex-end', padding: 24, alignItems: 'center', gap: 16 },
  endBtn: { paddingVertical: 14, paddingHorizontal: 32, borderRadius: 14, borderWidth: 2 },
  endBtnText: { fontWeight: '700', fontSize: 15 },
  resultHeader: { padding: 24 },
  resultTitle: { fontSize: 24, fontWeight: '800', color: Colors.shadowGrey },
  scoreGrid: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 16, gap: 10 },
  scoreCard: { width: '30%', flexGrow: 1, backgroundColor: Colors.white, borderRadius: 14, padding: 16, alignItems: 'center' },
  scoreValue: { fontSize: 28, fontWeight: '800', color: Colors.shadowGrey },
  scoreLabel: { fontSize: 10, color: Colors.mutedText, textAlign: 'center', marginTop: 6 },
  summary: { padding: 24, fontSize: 15, color: Colors.mutedText, lineHeight: 22 },
});
