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
import { Colors, Shadow } from '../src/theme';

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

        {/* Professional card */}
        <PressScale onPress={goProfessional} scale={0.97} style={styles.card}>
          <View style={styles.cardHeader}>
            <Text style={styles.cardTitle}>
              {t("I'm a Professional", 'मैं एक प्रोफेशनल हूं')}
            </Text>
            <ArrowCircle accent={accent} />
          </View>
          <Text style={styles.cardDescription}>
            {t(
              'Create your verified work profile. Electricians, plumbers, mechanics & 50+ trades.',
              'अपनी सत्यापित वर्क प्रोफ़ाइल बनाएं। इलेक्ट्रीशियन, प्लंबर, मैकेनिक और 50+ काम।',
            )}
          </Text>
          <View style={styles.chipRow}>
            <Chip label={t('Free', 'मुफ्त')} accent={accent} />
            <Chip label={t('30 sec setup', '30 सेकंड सेटअप')} accent={accent} />
            <Chip label={t('Get hired', 'काम पाएं')} accent={accent} />
          </View>
        </PressScale>

        {/* Explore card */}
        <PressScale onPress={goExplore} scale={0.97} style={[styles.card, { marginTop: 12 }]}>
          <Text style={styles.cardTitle}>
            {t('Explore Workers', 'कामगार खोजें')}
          </Text>
          <Text style={styles.cardDescription}>
            {t(
              'Browse skilled professionals near you',
              'आपके पास के कुशल प्रोफेशनल देखें',
            )}
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
  card: {
    backgroundColor: '#fff',
    borderRadius: 20,
    padding: 20,
    ...Shadow.card,
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: Colors.shadowGrey,
  },
  cardDescription: {
    fontSize: 14,
    color: Colors.mutedText,
    lineHeight: 20,
    marginBottom: 14,
  },
  chipRow: {
    flexDirection: 'row',
    gap: 8,
    flexWrap: 'wrap',
  },
});
