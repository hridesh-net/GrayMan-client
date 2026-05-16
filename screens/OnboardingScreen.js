import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { LinearGradient } from 'expo-linear-gradient';

import { useTheme } from '../src/AppTheme';
import Blobs from '../src/components/Blobs';
import PressScale from '../src/components/PressScale';
import { AppLanguages } from '../src/i18n';
import { Colors, Spacing, Shadow } from '../src/theme';

export default function OnboardingScreen({ goNext }) {
  const { accent, language, setLanguage, t } = useTheme();

  const row1 = AppLanguages.slice(0, 3);
  const row2 = AppLanguages.slice(3);

  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <StatusBar style="dark" />
      <Blobs accent={accent} opacity={1.0} />

      {/* Center content */}
      <View style={styles.centerContent}>
        <LinearGradient
          colors={[Colors.shadowGrey, accent]}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.logoBox}
        >
          <Text style={styles.logoEmoji}>⚡</Text>
        </LinearGradient>

        <Text style={styles.appTitle}>GrayMan</Text>

        <Text style={styles.subtitle}>
          {t(
            'Digital identity for skilled workers',
            'कुशल कामगारों की डिजिटल पहचान',
            {
              mr: 'कुशल कामगारांची डिजिटल ओळख',
              te: 'నైపుణ్య కార్మికుల డిజిటల్ గుర్తింపు',
              ta: 'திறன் தொழிலாளர்களின் டிஜிட்டல் அடையாளம்',
              kn: 'ಕೌಶಲ್ಯ ಕಾರ್ಮಿಕರ ಡಿಜಿಟಲ್ ಗುರುತು',
            },
          )}
        </Text>

        <Text style={[styles.devanagariTag, { color: accent }]}>काम · सेतु</Text>
      </View>

      {/* Bottom CTA section */}
      <View style={styles.bottomSection}>
        <PressScale onPress={goNext} style={[styles.primaryBtn, { backgroundColor: accent, shadowColor: accent }]}>
          <Text style={styles.primaryBtnText}>
            {t('Get Started', 'शुरू करें')} →
          </Text>
        </PressScale>

        <PressScale onPress={goNext} style={styles.secondaryBtn}>
          <Text style={styles.secondaryBtnText}>{t('Sign In', 'साइन इन करें')}</Text>
        </PressScale>

        <Text style={styles.termsText}>
          {t(
            'By continuing you agree to our Terms & Privacy',
            'जारी रखकर आप हमारी शर्तों और गोपनीयता से सहमत हैं',
          )}
        </Text>
      </View>

      {/* Language pill grid — pinned above safe-area bottom */}
      <View style={styles.langGrid}>
        <View style={styles.langRow}>
          {row1.map(lang => {
            const selected = language === lang.key;
            return (
              <TouchableOpacity
                key={lang.key}
                onPress={() => setLanguage(lang.key)}
                style={[
                  styles.langPill,
                  selected
                    ? { backgroundColor: accent }
                    : { backgroundColor: Colors.soft },
                ]}
                activeOpacity={0.75}
              >
                <Text
                  style={[
                    styles.langPillText,
                    { color: selected ? '#fff' : Colors.shadowGrey },
                  ]}
                >
                  {lang.shortCode}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>
        <View style={[styles.langRow, { marginTop: 6 }]}>
          {row2.map(lang => {
            const selected = language === lang.key;
            return (
              <TouchableOpacity
                key={lang.key}
                onPress={() => setLanguage(lang.key)}
                style={[
                  styles.langPill,
                  selected
                    ? { backgroundColor: accent }
                    : { backgroundColor: Colors.soft },
                ]}
                activeOpacity={0.75}
              >
                <Text
                  style={[
                    styles.langPillText,
                    { color: selected ? '#fff' : Colors.shadowGrey },
                  ]}
                >
                  {lang.shortCode}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: Colors.canvas,
  },
  centerContent: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  logoBox: {
    width: 82,
    height: 82,
    borderRadius: 26,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 20,
  },
  logoEmoji: {
    fontSize: 34,
    color: '#fff',
  },
  appTitle: {
    fontSize: 44,
    fontWeight: '800',
    color: Colors.shadowGrey,
    letterSpacing: -1.5,
    marginBottom: 10,
  },
  subtitle: {
    fontSize: 16,
    color: Colors.mutedText,
    textAlign: 'center',
    maxWidth: 260,
    lineHeight: 22,
    marginBottom: 14,
  },
  devanagariTag: {
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 0.6,
  },

  // Bottom section
  bottomSection: {
    paddingHorizontal: 24,
    paddingBottom: 100,
    alignItems: 'center',
  },
  primaryBtn: {
    width: '100%',
    paddingVertical: 17,
    borderRadius: 16,
    alignItems: 'center',
    marginBottom: 12,
    ...Shadow.button,
  },
  primaryBtnText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
  },
  secondaryBtn: {
    width: '100%',
    paddingVertical: 17,
    borderRadius: 16,
    alignItems: 'center',
    borderWidth: 1.5,
    borderColor: 'rgba(39,41,50,0.18)',
    marginBottom: 16,
  },
  secondaryBtnText: {
    color: Colors.shadowGrey,
    fontSize: 16,
    fontWeight: '600',
  },
  termsText: {
    fontSize: 12,
    color: Colors.dimText,
    textAlign: 'center',
    lineHeight: 17,
  },

  // Language pills
  langGrid: {
    position: 'absolute',
    bottom: 32,
    left: 0,
    right: 0,
    alignItems: 'center',
  },
  langRow: {
    flexDirection: 'row',
    gap: 8,
  },
  langPill: {
    width: 52,
    height: 32,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  langPillText: {
    fontSize: 13,
    fontWeight: '600',
  },
});
