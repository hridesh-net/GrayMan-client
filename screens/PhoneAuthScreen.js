import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';

import { useTheme } from '../src/AppTheme';
import Blobs from '../src/components/Blobs';
import PressScale from '../src/components/PressScale';
import { workerService } from '../src/api/workerService';
import { tokenStore } from '../src/api/tokenStore';
import { Colors } from '../src/theme';

function OtpBoxes({ code, accent }) {
  const boxes = [0, 1, 2, 3, 4, 5];
  const activeIndex = Math.min(code.length, 5);
  return (
    <View style={otp.row}>
      {boxes.map(i => {
        const char = code[i] ?? '';
        const isActive = i === code.length;
        const isFilled = char !== '';
        
        return (
          <View
            key={i}
            style={[
              otp.box,
              isActive ? { backgroundColor: `${accent}14`, borderWidth: 2, borderColor: accent } : { backgroundColor: Colors.soft, borderWidth: 2, borderColor: 'transparent' }
            ]}
          >
            <Text style={[otp.digit, isFilled ? { color: Colors.shadowGrey } : { color: 'rgba(39,41,50,0.3)' }]}>
              {char}
            </Text>
          </View>
        );
      })}
    </View>
  );
}

const otp = StyleSheet.create({
  row: { flexDirection: 'row', gap: 8 },
  box: {
    width: 48,
    height: 64,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  digit: { fontSize: 26, fontWeight: '900' },
});

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
      <Blobs accent={accent} opacity={0.6} />

      <View style={styles.header}>
        <PressScale onPress={stage === 'otp' ? () => { setStage('phone'); setError(null); } : goBack} style={styles.backBtn}>
          <Text style={styles.backArrow}>←</Text>
        </PressScale>
      </View>

      <View style={styles.content}>
        <View style={styles.headlineGroup}>
          <Text style={styles.title}>
            {stage === 'otp' ? t('Enter OTP', 'OTP डालें') : t('Your number', 'आपका नंबर')}
          </Text>
          <Text style={styles.subtitle}>
            {stage === 'otp'
              ? t(`Code sent to +91 ${phone}`, `+91 ${phone} पर कोड भेजा गया`)
              : t("We'll send a verification code", 'हम एक सत्यापन कोड भेजेंगे')}
          </Text>
        </View>

        {stage === 'phone' && (
          <View style={styles.phoneSection}>
            <View style={styles.inputRow}>
              <View style={styles.countryChip}>
                <Text>🇮🇳</Text>
                <Text style={styles.countryCode}>+91</Text>
                <Text style={styles.chevron}>▼</Text>
              </View>
              
              <TextInput
                style={styles.phoneInput}
                value={phone}
                onChangeText={val => setPhone(val.replace(/\D/g, '').slice(0, 10))}
                keyboardType="phone-pad"
                placeholder={t('Mobile number', 'मोबाइल नंबर')}
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
          </View>
        )}

        {stage === 'otp' && (
          <View style={styles.otpSection}>
            <View style={styles.otpBoxContainer}>
              <OtpBoxes code={code} accent={accent} />
              <TextInput
                ref={otpInputRef}
                value={code}
                onChangeText={val => setCode(val.replace(/\D/g, '').slice(0, 6))}
                keyboardType="number-pad"
                autoFocus
                style={styles.hiddenInput}
              />
            </View>

            <View style={[styles.autoReadRow, { backgroundColor: `${accent}14` }]}>
              <View style={[styles.autoReadDot, { backgroundColor: accent }]} />
              <Text style={[styles.autoReadText, { color: accent }]}>
                {t('Auto-reading code from messages…', 'संदेशों से कोड ऑटो-पढ़ रहे हैं…')}
              </Text>
            </View>

            <View style={styles.resendRow}>
              <Text style={styles.resendHint}>{t("Didn't get it?", "नहीं मिला?")}</Text>
              <PressScale onPress={() => { setCode(''); handleContinue(); }}>
                <Text style={[styles.resendAction, { color: accent }]}>
                  {t('Resend code', 'कोड दोबारा भेजें')}
                </Text>
              </PressScale>
            </View>
          </View>
        )}

        {error && (
          <Text style={styles.errorText}>{error}</Text>
        )}
      </View>

      <View style={styles.bottomSection}>
        <PressScale
          onPress={handleContinue}
          disabled={!canProceed || loading}
          style={[styles.ctaBtn, { backgroundColor: canProceed ? accent : 'rgba(157,161,173,0.4)', shadowColor: canProceed ? accent : 'transparent', elevation: canProceed ? 6 : 0 }]}
        >
          {loading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.ctaBtnText}>
              {stage === 'otp' ? t('Verify & Continue', 'सत्यापित करें और जारी रखें') : t('Continue with Phone', 'फ़ोन से जारी रखें')}
            </Text>
          )}
        </PressScale>
        
        <Text style={styles.disclaimerText}>
          {t('SMS · WhatsApp auto-detection enabled', 'SMS · WhatsApp ऑटो-डिटेक्शन सक्षम')}
        </Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.canvas },
  header: { paddingHorizontal: 22, paddingTop: 8 },
  backBtn: { width: 40, height: 40, borderRadius: 14, backgroundColor: Colors.soft, alignItems: 'center', justifyContent: 'center' },
  backArrow: { fontSize: 16, color: Colors.shadowGrey, fontWeight: 'bold' },
  
  content: { flex: 1 },
  
  headlineGroup: {
    paddingHorizontal: 28,
    paddingTop: 36,
    paddingBottom: 36,
  },
  title: { fontSize: 30, fontWeight: '900', color: Colors.shadowGrey, letterSpacing: -1, marginBottom: 7 },
  subtitle: { fontSize: 15, color: Colors.mutedText },
  
  phoneSection: {
    paddingHorizontal: 28,
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.soft,
    borderRadius: 18,
    paddingLeft: 16,
    paddingRight: 4,
    paddingVertical: 4,
    marginBottom: 12,
  },
  countryChip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginRight: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 2,
    gap: 6,
  },
  countryCode: { fontSize: 14, fontWeight: '900', color: Colors.shadowGrey },
  chevron: { fontSize: 10, color: Colors.dimText, fontWeight: 'bold' },
  
  phoneInput: { flex: 1, fontSize: 17, fontWeight: '500', color: Colors.shadowGrey, letterSpacing: 0.7, height: 40 },
  checkCircle: { width: 40, height: 40, borderRadius: 13, alignItems: 'center', justifyContent: 'center' },
  checkMark: { color: '#fff', fontWeight: '900', fontSize: 17 },
  
  inputLabel: { fontSize: 11, color: Colors.dimText, letterSpacing: 0.8, fontWeight: '900' },
  
  otpSection: {
    alignItems: 'center',
  },
  otpBoxContainer: {
    marginBottom: 20,
    position: 'relative',
  },
  hiddenInput: { position: 'absolute', opacity: 0.001, width: '100%', height: 64 },
  
  autoReadRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 14,
    marginBottom: 20,
    marginHorizontal: 28,
    alignSelf: 'stretch',
    gap: 10,
  },
  autoReadDot: { width: 8, height: 8, borderRadius: 4 },
  autoReadText: { fontSize: 13, fontWeight: '600' },
  
  resendRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  resendHint: { fontSize: 13, color: Colors.dimText },
  resendAction: { fontSize: 13, fontWeight: 'bold' },
  
  errorText: { fontSize: 13, fontWeight: '600', color: '#E63946', paddingHorizontal: 28, paddingTop: 14 },
  
  bottomSection: { paddingHorizontal: 24, paddingBottom: 32 },
  ctaBtn: { paddingVertical: 17, borderRadius: 16, alignItems: 'center', shadowOffset: { width: 0, height: 6 }, shadowOpacity: 0.36, shadowRadius: 12, marginBottom: 12 },
  ctaBtnText: { color: '#fff', fontSize: 16, fontWeight: 'bold' },
  disclaimerText: { fontSize: 12, color: Colors.dimText, textAlign: 'center' }
});
