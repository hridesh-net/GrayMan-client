import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Animated,
  Easing,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';

import { useTheme } from '../src/AppTheme';
import Blobs from '../src/components/Blobs';
import PressScale from '../src/components/PressScale';
import { workerService } from '../src/api/workerService';
import { tokenStore } from '../src/api/tokenStore';
import { Colors, Shadow } from '../src/theme';

function OtpBoxes({ code, accent }) {
  const boxes = [0, 1, 2, 3, 4, 5];
  const activeIndex = Math.min(code.length, 5);
  return (
    <View style={otp.row}>
      {boxes.map(i => {
        const char = code[i] ?? '';
        const isActive = i === activeIndex;
        return (
          <View
            key={i}
            style={[otp.box, isActive && { borderWidth: 2, borderColor: accent }]}
          >
            <Text style={otp.digit}>{char || (isActive ? '|' : '')}</Text>
          </View>
        );
      })}
    </View>
  );
}

const otp = StyleSheet.create({
  row: { flexDirection: 'row', gap: 8, marginTop: 8, flexWrap: 'wrap' },
  box: {
    width: 44,
    height: 52,
    borderRadius: 12,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: 'transparent',
  },
  digit: { fontSize: 20, fontWeight: '700', color: Colors.shadowGrey },
});

function PulseDot({ accent }) {
  const opacity = useRef(new Animated.Value(0.3)).current;
  useEffect(() => {
    Animated.loop(
      Animated.sequence([
        Animated.timing(opacity, { toValue: 1, duration: 600, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
        Animated.timing(opacity, { toValue: 0.3, duration: 600, easing: Easing.inOut(Easing.ease), useNativeDriver: true }),
      ]),
    ).start();
  }, [opacity]);
  return (
    <Animated.View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: accent, opacity, marginRight: 8 }} />
  );
}

export default function PhoneAuthScreen({ goBack, goNext }) {
  const { accent, t } = useTheme();
  const [stage, setStage] = useState('phone');
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const otpInputRef = useRef(null);

  const e164 = `+91${phone.replace(/\D/g, '')}`;
  const phoneComplete = phone.replace(/\D/g, '').length === 10;
  const canProceed = stage === 'phone' ? phoneComplete : code.length === 6;

  const handleContinue = async () => {
    setError(null);
    if (stage === 'phone') {
      if (!phoneComplete) return;
      setLoading(true);
      try {
        await workerService.sendOTP(e164);
        setStage('otp');
        setCode('');
      } catch (e) {
        setError(e.message || 'Could not send code');
      } finally {
        setLoading(false);
      }
      return;
    }

    if (code.length !== 6) return;
    setLoading(true);
    try {
      const res = await workerService.verifyOTP(e164, code);
      await tokenStore.save(res.access_token, res.worker_id);
      goNext({ isNew: res.is_new_worker });
    } catch (e) {
      setError(e.status === 401 ? t('Invalid code', 'गलत कोड') : (e.message || 'Verification failed'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <StatusBar style="dark" />
      <Blobs accent={accent} opacity={0.5} />

      <View style={styles.header}>
        <PressScale onPress={stage === 'otp' ? () => { setStage('phone'); setError(null); } : goBack} style={styles.backBtn}>
          <Text style={styles.backArrow}>←</Text>
        </PressScale>
      </View>

      <View style={styles.content}>
        <Text style={styles.title}>
          {stage === 'otp' ? t('Enter OTP', 'OTP डालें') : t('Your number', 'आपका नंबर')}
        </Text>
        <Text style={styles.subtitle}>
          {stage === 'otp'
            ? `${t('Code sent to', 'कोड भेजा गया')} +91 ${phone}`
            : t("We'll send a verification code", 'हम एक सत्यापन कोड भेजेंगे')}
        </Text>
        {error ? <Text style={styles.errorText}>{error}</Text> : null}

        {stage === 'phone' && (
          <>
            <View style={styles.inputRow}>
              <View style={styles.countryBox}>
                <Text style={styles.flagText}>🇮🇳</Text>
                <Text style={styles.dialCode}>+91</Text>
              </View>
              <TextInput
                style={styles.phoneInput}
                value={phone}
                onChangeText={val => setPhone(val.replace(/\D/g, '').slice(0, 10))}
                keyboardType="numeric"
                placeholder={t('Enter number', 'नंबर दर्ज करें')}
                placeholderTextColor={Colors.dimText}
                autoFocus
              />
              {phoneComplete && (
                <View style={[styles.checkCircle, { backgroundColor: accent }]}>
                  <Text style={styles.checkMark}>✓</Text>
                </View>
              )}
            </View>
            <Text style={styles.inputLabel}>{t('MOBILE NUMBER', 'मोबाइल नंबर')}</Text>
          </>
        )}

        {stage === 'otp' && (
          <>
            <TextInput
              ref={otpInputRef}
              value={code}
              onChangeText={val => setCode(val.replace(/\D/g, '').slice(0, 6))}
              keyboardType="numeric"
              autoFocus
              style={styles.hiddenInput}
            />
            <OtpBoxes code={code} accent={accent} />
            <View style={styles.autoReadRow}>
              <PulseDot accent={accent} />
              <Text style={styles.autoReadText}>
                {t('Check server logs for OTP in dev', 'डेव में सर्वर लॉग में OTP देखें')}
              </Text>
            </View>
          </>
        )}
      </View>

      <View style={styles.bottomSection}>
        <PressScale
          onPress={handleContinue}
          disabled={!canProceed || loading}
          style={[styles.ctaBtn, { backgroundColor: accent, shadowColor: accent }, (!canProceed || loading) && { opacity: 0.4 }]}
        >
          {loading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.ctaBtnText}>
              {stage === 'otp' ? t('Verify', 'सत्यापित करें') : t('Continue', 'जारी रखें')}
            </Text>
          )}
        </PressScale>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.canvas },
  header: { paddingHorizontal: 20, paddingTop: 8 },
  backBtn: { width: 36, height: 36, borderRadius: 12, backgroundColor: Colors.soft, alignItems: 'center', justifyContent: 'center' },
  backArrow: { fontSize: 18, color: Colors.shadowGrey, fontWeight: '600' },
  content: { flex: 1, paddingHorizontal: 24, paddingTop: 24 },
  title: { fontSize: 26, fontWeight: '800', color: Colors.shadowGrey, marginBottom: 8 },
  subtitle: { fontSize: 15, color: Colors.mutedText, marginBottom: 16 },
  errorText: { fontSize: 14, color: '#DC2626', marginBottom: 12 },
  inputRow: { flexDirection: 'row', alignItems: 'center', backgroundColor: Colors.soft, borderRadius: 16, paddingHorizontal: 14, paddingVertical: 14, marginBottom: 8 },
  countryBox: { flexDirection: 'row', alignItems: 'center', gap: 4, marginRight: 10, paddingRight: 10, borderRightWidth: 1, borderRightColor: 'rgba(39,41,50,0.12)' },
  flagText: { fontSize: 20 },
  dialCode: { fontSize: 15, fontWeight: '700', color: Colors.shadowGrey },
  phoneInput: { flex: 1, fontSize: 18, fontWeight: '600', color: Colors.shadowGrey },
  checkCircle: { width: 28, height: 28, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  checkMark: { color: '#fff', fontWeight: '800', fontSize: 14 },
  inputLabel: { fontSize: 11, color: Colors.dimText, letterSpacing: 1, fontWeight: '600' },
  hiddenInput: { position: 'absolute', opacity: 0, width: 1, height: 1 },
  autoReadRow: { flexDirection: 'row', alignItems: 'center', marginTop: 20 },
  autoReadText: { fontSize: 13, color: Colors.mutedText, flex: 1 },
  bottomSection: { paddingHorizontal: 24, paddingBottom: 24 },
  ctaBtn: { paddingVertical: 17, borderRadius: 16, alignItems: 'center', ...Shadow.button },
  ctaBtnText: { color: '#fff', fontSize: 16, fontWeight: '700' },
});
