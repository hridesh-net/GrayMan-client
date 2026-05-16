import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';

import { useTheme } from '../src/AppTheme';
import Blobs from '../src/components/Blobs';
import PressScale from '../src/components/PressScale';
import { AppLanguages } from '../src/i18n';
import { Colors, Spacing, Radius, Shadow } from '../src/theme';

function SectionLabel({ children }) {
  return <Text style={styles.sectionLabel}>{children}</Text>;
}

function Card({ children }) {
  return <View style={styles.card}>{children}</View>;
}

function RowDivider() {
  return <View style={styles.divider} />;
}

export default function SettingsScreen({ onClose }) {
  const { accent, language, setLanguage, t } = useTheme();

  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <StatusBar style="dark" />
      <Blobs accent={accent} opacity={0.45} />

      {/* Header */}
      <View style={styles.header}>
        <PressScale onPress={onClose} style={styles.closeBtn}>
          <Text style={styles.closeBtnText}>✕</Text>
        </PressScale>
        <Text style={styles.headerTitle}>{t('Settings', 'सेटिंग्स')}</Text>
        <View style={{ width: 36 }} />
      </View>

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {/* Language section */}
        <SectionLabel>{t('LANGUAGE', 'भाषा').toUpperCase()}</SectionLabel>
        <Card>
          {AppLanguages.map((lang, index) => {
            const selected = language === lang.key;
            const isLast = index === AppLanguages.length - 1;
            return (
              <React.Fragment key={lang.key}>
                <TouchableOpacity
                  onPress={() => setLanguage(lang.key)}
                  style={styles.langRow}
                  activeOpacity={0.75}
                >
                  {/* Short code badge */}
                  <View
                    style={[
                      styles.shortCodeBadge,
                      selected
                        ? { backgroundColor: accent }
                        : { backgroundColor: Colors.soft },
                    ]}
                  >
                    <Text
                      style={[
                        styles.shortCodeText,
                        { color: selected ? '#fff' : Colors.shadowGrey },
                      ]}
                    >
                      {lang.shortCode}
                    </Text>
                  </View>

                  {/* Name + native */}
                  <View style={styles.langNameBlock}>
                    <Text style={styles.langDisplayName}>{lang.displayName}</Text>
                    {lang.key !== 'en' && (
                      <Text style={styles.langNative}>{lang.displayName}</Text>
                    )}
                  </View>

                  {/* Radio indicator */}
                  <View
                    style={[
                      styles.radio,
                      selected && { borderColor: accent },
                    ]}
                  >
                    {selected && (
                      <View style={[styles.radioDot, { backgroundColor: accent }]} />
                    )}
                  </View>
                </TouchableOpacity>
                {!isLast && <RowDivider />}
              </React.Fragment>
            );
          })}
        </Card>

        {/* Appearance section */}
        <SectionLabel>{t('APPEARANCE', 'दिखावट').toUpperCase()}</SectionLabel>
        <Card>
          <View style={styles.appearanceRow}>
            <View style={[styles.accentDot, { backgroundColor: accent }]} />
            <View style={styles.appearanceTextBlock}>
              <Text style={styles.appearanceLabel}>{t('Accent Colour', 'एक्सेंट रंग')}</Text>
              <Text style={styles.appearanceSub}>
                {t(
                  'Use the 🎨 button on any screen to change',
                  'किसी भी स्क्रीन पर 🎨 बटन से बदलें',
                )}
              </Text>
            </View>
          </View>
        </Card>

        {/* About section */}
        <SectionLabel>{t('ABOUT', 'जानकारी').toUpperCase()}</SectionLabel>
        <Card>
          <View style={styles.aboutRow}>
            <Text style={styles.aboutLabel}>{t('GrayMan Version', 'GrayMan संस्करण')}</Text>
            <Text style={styles.aboutValue}>1.0</Text>
          </View>
          <RowDivider />
          <TouchableOpacity style={styles.aboutLinkRow} activeOpacity={0.75}>
            <Text style={styles.aboutLinkText}>{t('Privacy Policy', 'गोपनीयता नीति')}</Text>
            <Text style={styles.aboutArrow}>→</Text>
          </TouchableOpacity>
          <RowDivider />
          <TouchableOpacity style={styles.aboutLinkRow} activeOpacity={0.75}>
            <Text style={styles.aboutLinkText}>{t('Terms of Service', 'सेवा की शर्तें')}</Text>
            <Text style={styles.aboutArrow}>→</Text>
          </TouchableOpacity>
        </Card>

        <View style={{ height: 20 }} />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.canvas },
  scroll: { flex: 1 },
  scrollContent: { paddingHorizontal: Spacing.lg, paddingTop: 4, paddingBottom: 32 },

  // Header
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.lg,
    paddingTop: 8,
    paddingBottom: 12,
  },
  closeBtn: {
    width: 36,
    height: 36,
    borderRadius: 12,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  closeBtnText: { fontSize: 15, fontWeight: '700', color: Colors.shadowGrey },
  headerTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: Colors.shadowGrey,
    letterSpacing: -0.3,
  },

  // Section label
  sectionLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: Colors.dimText,
    letterSpacing: 1,
    marginBottom: 8,
    marginTop: 20,
    marginLeft: 4,
  },

  // Card
  card: {
    backgroundColor: Colors.white,
    borderRadius: 18,
    overflow: 'hidden',
    ...Shadow.card,
  },

  divider: {
    height: 1,
    backgroundColor: Colors.soft,
    marginHorizontal: 16,
  },

  // Language row
  langRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 13,
    gap: 14,
  },
  shortCodeBadge: {
    width: 40,
    height: 40,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  shortCodeText: { fontSize: 16, fontWeight: '700' },
  langNameBlock: { flex: 1 },
  langDisplayName: { fontSize: 15, fontWeight: '600', color: Colors.shadowGrey },
  langNative: { fontSize: 12, color: Colors.mutedText, marginTop: 1 },
  radio: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 2,
    borderColor: Colors.dimText,
    alignItems: 'center',
    justifyContent: 'center',
  },
  radioDot: { width: 10, height: 10, borderRadius: 5 },

  // Appearance
  appearanceRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    gap: 14,
  },
  accentDot: { width: 28, height: 28, borderRadius: 14 },
  appearanceTextBlock: { flex: 1 },
  appearanceLabel: { fontSize: 15, fontWeight: '600', color: Colors.shadowGrey },
  appearanceSub: { fontSize: 12, color: Colors.mutedText, marginTop: 2, lineHeight: 16 },

  // About
  aboutRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  aboutLabel: { fontSize: 15, fontWeight: '500', color: Colors.shadowGrey },
  aboutValue: { fontSize: 14, color: Colors.mutedText, fontWeight: '500' },
  aboutLinkRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  aboutLinkText: { fontSize: 15, fontWeight: '500', color: Colors.shadowGrey },
  aboutArrow: { fontSize: 15, color: Colors.dimText, fontWeight: '500' },
});
