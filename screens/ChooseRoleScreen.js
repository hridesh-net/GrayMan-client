import React from 'react';
import {
  View,
  Text,
  StyleSheet,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';

import { useTheme } from '../src/AppTheme';
import Blobs from '../src/components/Blobs';
import PressScale from '../src/components/PressScale';
import { Colors, Shadow, Glass, hexToRgba } from '../src/theme';
import { BlurView } from 'expo-blur';
import { LinearGradient } from 'expo-linear-gradient';

// Small chip pill used inside the professional card
function Chip({ label, accent }) {
  return (
    <View style={[chip.pill, { backgroundColor: Colors.soft }]}>
      <Text style={[chip.text, { color: accent }]}>{label}</Text>
    </View>
  );
}

const chip = StyleSheet.create({
  pill: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 20,
  },
  text: {
    fontSize: 12,
    fontWeight: '600',
  },
});

// Arrow circle shown on the professional card header
function ArrowCircle({ accent }) {
  return (
    <View style={[arrowCircle.circle, { backgroundColor: accent }]}>
      <Text style={arrowCircle.arrow}>→</Text>
    </View>
  );
}

const arrowCircle = StyleSheet.create({
  circle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  arrow: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
  },
});

// Main screen ----------------------------------------------------------------
export default function ChooseRoleScreen({ name, goBack, goProfessional, goExplore }) {
  const { accent, t } = useTheme();

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
        {/* Welcome tag */}
        <Text style={styles.welcomeTag}>
          {t('WELCOME ABOARD', 'स्वागत है')}
        </Text>

        {/* Greeting */}
        <Text style={styles.greeting}>
          {t(
            `Hey ${name} 👋\nWhat brings\nyou here?`,
            `नमस्ते ${name} 👋\nआप यहाँ\nकिसलिए आए?`,
          )}
        </Text>

        {/* Subtitle */}
        <Text style={styles.subtitle}>
          {t(
            "Choose how you'd like to use GrayMan",
            'GrayMan का उपयोग कैसे करना चाहते हैं?',
          )}
        </Text>

        {/* Professional card - Glass */}
        <PressScale onPress={goProfessional} scale={0.97} style={styles.proCardPress}>
          <BlurView intensity={28} tint="light" style={styles.proCard}>
            <View style={styles.proCardTopRow}>
              <View style={styles.proIconBox}>
                <LinearGradient
                  colors={[Colors.shadowGrey, accent]}
                  start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }}
                  style={StyleSheet.absoluteFill}
                  borderRadius={16}
                />
                <Text style={styles.proIconText}>🔧</Text>
              </View>
              <View style={styles.proCardTextCol}>
                <Text style={styles.cardTitle}>{t("I'm a Professional", 'मैं एक प्रोफेशनल हूं')}</Text>
                <Text style={styles.cardDescription}>
                  {t(
                    'Create your verified work profile. Electricians, plumbers, mechanics & 50+ trades.',
                    'अपनी सत्यापित वर्क प्रोफ़ाइल बनाएं। इलेक्ट्रीशियन, प्लंबर, मैकेनिक और 50+ काम।'
                  )}
                </Text>
              </View>
              <Text style={styles.arrowIcon}>→</Text>
            </View>
            <View style={styles.divider} />
            <View style={styles.chipRow}>
              <Chip label={t('Free', 'मुफ्त')} accent={accent} />
              <Chip label={t('30 sec setup', '30 सेकंड सेटअप')} accent={accent} />
              <Chip label={t('Get hired', 'काम पाएं')} accent={accent} />
            </View>
          </BlurView>
        </PressScale>

        {/* Explore card - Outlined */}
        <PressScale onPress={goExplore} scale={0.97} style={[styles.exploreCard, { marginTop: 14 }]}>
          <View style={styles.exploreIconBox}>
            <Text style={styles.exploreIconText}>🔍</Text>
          </View>
          <View style={styles.proCardTextCol}>
            <Text style={styles.exploreTitle}>{t('Explore Workers', 'कामगार खोजें')}</Text>
            <Text style={styles.exploreDesc}>
              {t('Browse skilled professionals near you', 'आपके पास के कुशल प्रोफेशनल देखें')}
            </Text>
          </View>
          <Text style={styles.arrowIcon}>→</Text>
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
    paddingTop: 20,
  },
  welcomeTag: {
    fontSize: 11,
    color: Colors.dimText,
    letterSpacing: 1,
    fontWeight: '600',
    textTransform: 'uppercase',
    marginBottom: 10,
  },
  greeting: {
    fontSize: 34,
    fontWeight: '800',
    color: Colors.shadowGrey,
    lineHeight: 42,
    marginBottom: 10,
  },
  subtitle: {
    fontSize: 15,
    color: Colors.mutedText,
    marginBottom: 28,
  },

  // Cards
  proCardPress: {
    borderRadius: 24,
    overflow: 'hidden',
    ...Shadow.card,
  },
  proCard: {
    padding: 22,
    backgroundColor: Glass.dark.backgroundColor,
    borderColor: Glass.dark.borderColor,
    borderWidth: 1,
    borderRadius: 24,
  },
  proCardTopRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 14,
  },
  proIconBox: {
    width: 52,
    height: 52,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  proIconText: {
    fontSize: 24,
  },
  proCardTextCol: {
    flex: 1,
  },
  cardTitle: {
    fontSize: 17,
    fontWeight: '800',
    color: Colors.shadowGrey,
    letterSpacing: -0.5,
    marginBottom: 4,
  },
  cardDescription: {
    fontSize: 13,
    color: Colors.mutedText,
    lineHeight: 18,
  },
  arrowIcon: {
    fontSize: 20,
    color: Colors.dimText,
    alignSelf: 'center',
  },
  divider: {
    height: 1,
    backgroundColor: 'rgba(0,0,0,0.06)',
    marginTop: 14,
    marginBottom: 14,
  },
  chipRow: {
    flexDirection: 'row',
    gap: 8,
    flexWrap: 'wrap',
  },
  exploreCard: {
    borderRadius: 20,
    padding: 18,
    borderWidth: 1.5,
    borderColor: 'rgba(0,0,0,0.12)',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    backgroundColor: 'transparent',
  },
  exploreIconBox: {
    width: 48,
    height: 48,
    borderRadius: 14,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  exploreIconText: {
    fontSize: 22,
  },
  exploreTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: Colors.shadowGrey,
    marginBottom: 2,
  },
  exploreDesc: {
    fontSize: 13,
    color: Colors.dimText,
  },
});
