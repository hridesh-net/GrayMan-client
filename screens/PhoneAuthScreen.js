import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Animated,
  Easing,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';

import { useTheme } from '../src/AppTheme';
import Blobs from '../src/components/Blobs';
import PressScale from '../src/components/PressScale';
import { Colors, Shadow } from '../src/theme';

// Four-box OTP display -------------------------------------------------------
function OtpBoxes({ code, accent }) {
  const boxes = [0, 1, 2, 3];
  const activeIndex = Math.min(code.length, 3);

  return (
    <View style={otp.row}>
      {boxes.map(i => {
        const char = code[i] ?? '';
        const isActive = i === activeIndex;
        return (
          <View
            key={i}
            style={[
              otp.box,
              isActive && { borderWidth: 2, borderColor: accent },
            ]}
          >
            <Text style={otp.digit}>{char || (isActive ? '|' : '')}</Text>
          </View>
        );
      })}
    </View>
  );
}

const otp = StyleSheet.create({
  row: { flexDirection: 'row', gap: 12, marginTop: 8 },
  box: {
    width: 56,
    height: 64,
    borderRadius: 12,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: 'transparent',
  },
  digit: { fontSize: 24, fontWeight: '700', color: Colors.shadowGrey },
});

// Animated reading dot -------------------------------------------------------
function PulseDot({ accent }) {
  const opacity = useRef(new Animated.Value(0.3)).current;

  useEffect(() => {
    Animated.loop(
      Animated.sequence([
        Animated.timing(opacity, {
          toValue: 1,
          duration: 600,
          easing: Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
        Animated.timing(opacity, {
          toValue: 0.3,
          duration: 600,
          easing: Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
      ]),
    ).start();
  }, [opacity]);

  return (
    <Animated.View
      style={{
        width: 8,
        height: 8,
        borderRadius: 4,
        backgroundColor: accent,
        opacity,
        marginRight: 8,
      }}
    />
  );
}

// ----------------------------------------------------------------------------
export default function PhoneAuthScreen({ goBack, goNext }) {
  const { accent, t } = useTheme();

  const [stage, setStage] = useState('phone'); // 'phone' | 'otp'
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');

  const phoneInputRef = useRef(null);
  const otpInputRef = useRef(null);

  const phoneComplete = phone.replace(/\D/g, '').length === 10;

  const handleContinue = () => {
    if (stage === 'phone') {
      if (phoneComplete) setStage('otp');
    } else {
      if (code.length === 4) goNext();
    }
  };

  const canProceed = stage === 'phone' ? phoneComplete : code.length === 4;

  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <StatusBar style="dark" />
      <Blobs accent={accent} opacity={0.5} />

      {/* Back button */}
      <View style={styles.header}>
        <PressScale onPress={goBack} style={styles.backBtn}>
          <Text style={styles.backArrow}>←</Text>
        </PressScale>
      </View>

      <View style={styles.content}>
        {/* Title */}
        <Text style={styles.title}>
          {stage === 'otp' ? t('Enter OTP', 'OTP डालें') : t('Your number', 'आपका नंबर')}
        </Text>

        {/* Subtitle */}
        <Text style={styles.subtitle}>
          {stage === 'otp'
            ? `${t('Code sent to', 'कोड भेजा गया')} +91 ${phone}`
            : t("We'll send a verification code", 'हम एक सत्यापन कोड भेजेंगे')}
        </Text>

        {/* Phone stage */}
        {stage === 'phone' && (
          <>
            <View style={styles.inputRow}>
              <View style={styles.countryBox}>
                <Text style={styles.flagText}>🇮🇳</Text>
                <Text style={styles.dialCode}>+91</Text>
              </View>
              <TextInput
                ref={phoneInputRef}
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

        {/* OTP stage */}
        {stage === 'otp' && (
          <>
            {/* Hidden real TextInput that captures keyboard input */}
            <TextInput
              ref={otpInputRef}
              value={code}
              onChangeText={val => setCode(val.replace(/\D/g, '').slice(0, 4))}
              keyboardType="numeric"
              autoFocus
              style={styles.hiddenInput}
            />
            <OtpBoxes code={code} accent={accent} />

            <View style={styles.autoReadRow}>
              <PulseDot accent={accent} />
              <Text style={styles.autoReadText}>
                {t('Auto-reading code from messages…', 'संदेशों से कोड पढ़ा जा रहा है…')}
              </Text>
            </View>
          </>
        )}
      </View>

      {/* Bottom CTA */}
      <View style={styles.bottomSection}>
        <PressScale
          onPress={handleContinue}
          disabled={!canProceed}
          style={[
            styles.ctaBtn,
            { backgroundColor: accent, shadowColor: accent },
            !canProceed && { opacity: 0.4 },
          ]}
        >
          <Text style={styles.ctaBtnText}>
            {stage === 'otp' ? t('Verify', 'सत्यापित करें') : t('Continue', 'जारी रखें')}
          </Text>
        </PressScale>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: Colors.canvas,
  },
  header: {
    paddingHorizontal: 20,
    paddingTop: 8,
    paddingBottom: 4,
  },
  backBtn: {
    width: 36,
    height: 36,
    borderRadius: 12,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  backArrow: {
    fontSize: 18,
    color: Colors.shadowGrey,
    fontWeight: '600',
  },
  content: {
    flex: 1,
    paddingHorizontal: 24,
    paddingTop: 24,
  },
  title: {
    fontSize: 26,
    fontWeight: '800',
    color: Colors.shadowGrey,
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 15,
    color: Colors.mutedText,
    marginBottom: 32,
  },

  // Phone input row
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.soft,
    borderRadius: 16,
    paddingHorizontal: 14,
    paddingVertical: 14,
    marginBottom: 8,
  },
  countryBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginRight: 10,
    paddingRight: 10,
    borderRightWidth: 1,
    borderRightColor: 'rgba(39,41,50,0.12)',
  },
  flagText: { fontSize: 20 },
  dialCode: {
    fontSize: 15,
    fontWeight: '700',
    color: Colors.shadowGrey,
  },
  phoneInput: {
    flex: 1,
    fontSize: 18,
    fontWeight: '600',
    color: Colors.shadowGrey,
  },
  checkCircle: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkMark: {
    color: '#fff',
    fontWeight: '800',
    fontSize: 14,
  },
  inputLabel: {
    fontSize: 11,
    color: Colors.dimText,
    letterSpacing: 1,
    fontWeight: '600',
  },

  // OTP
  hiddenInput: {
    position: 'absolute',
    opacity: 0,
    width: 1,
    height: 1,
  },
  autoReadRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 20,
  },
  autoReadText: {
    fontSize: 13,
    color: Colors.mutedText,
  },

  // Bottom CTA
  bottomSection: {
    paddingHorizontal: 24,
    paddingBottom: 24,
  },
  ctaBtn: {
    paddingVertical: 17,
    borderRadius: 16,
    alignItems: 'center',
    ...Shadow.button,
  },
  ctaBtnText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
  },
});
