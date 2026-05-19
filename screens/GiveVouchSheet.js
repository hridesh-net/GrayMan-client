import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ScrollView,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';

import { useTheme } from '../src/AppTheme';
import PressScale from '../src/components/PressScale';
import VouchScoreRing from '../src/components/VouchScoreRing';
import { workerService } from '../src/api/workerService';
import { Colors, Spacing, Radius, Shadow } from '../src/theme';
import AppIcon, { Icons } from '../src/components/AppIcon';

const RELATIONSHIPS = [
  {
    en: 'We worked together',
    hi: 'हमने साथ काम किया',
    mr: 'आम्ही एकत्र काम केले',
    te: 'మేము కలిసి పని చేశాం',
    ta: 'நாங்கள் ஒன்றாக வேலை செய்தோம்',
    kn: 'ನಾವು ಒಟ್ಟಿಗೆ ಕೆಲಸ ಮಾಡಿದೆವು',
  },
  {
    en: 'They worked for me',
    hi: 'उन्होंने मेरे लिए काम किया',
    mr: 'त्यांनी माझ्यासाठी काम केले',
    te: 'వారు నా కోసం పని చేశారు',
    ta: 'அவர்கள் எனக்காக வேலை செய்தார்கள்',
    kn: 'ಅವರು ನನ್ನಿಗಾಗಿ ಕೆಲಸ ಮಾಡಿದರು',
  },
  {
    en: 'I was their client',
    hi: 'मैं उनका क्लाइंट था',
    mr: 'मी त्यांचा क्लायंट होतो',
    te: 'నేను వారి క్లయింట్',
    ta: 'நான் அவர்களின் வாடிக்கையாளர்',
    kn: 'ನಾನು ಅವರ ಕ್ಲೈಂಟ್',
  },
];

export default function GiveVouchSheet({ worker, onClose }) {
  const { accent, t } = useTheme();

  const [step, setStep] = useState('form'); // 'form' | 'success'
  const [selectedRelationship, setSelectedRelationship] = useState(-1);
  const [starRating, setStarRating] = useState(0);
  const [note, setNote] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const canSubmit = selectedRelationship >= 0 && starRating > 0;

  const handleSubmit = async () => {
    if (!canSubmit || !worker?.id) return;
    setSubmitting(true);
    try {
      const skillIndices = worker.tags?.length
        ? [0, 1].filter(i => i < worker.tags.length)
        : [0];
      await workerService.giveVouch(worker.id, skillIndices);
      setStep('success');
    } catch (e) {
      alert(e.message || 'Could not send vouch');
    } finally {
      setSubmitting(false);
    }
  };

  if (step === 'success') {
    return (
      <SafeAreaView style={styles.root} edges={['bottom']}>
        <StatusBar style="dark" />
        <View style={styles.successContent}>
          {/* Checkmark circle */}
          <View style={[styles.checkCircle, { backgroundColor: accent }]}>
            <AppIcon name={Icons.checkmark} size={36} color="#fff" />
          </View>
          <Text style={styles.successTitle}>{t('Vouch Sent!', 'वाउच भेज दिया!')}</Text>
          <Text style={styles.successBody}>
            {t(
              `Your endorsement for ${worker?.name ?? 'this worker'} has been recorded. Your trust helps build their reputation.`,
              `${worker?.name ?? 'इस कामगार'} के लिए आपका एंडोर्समेंट दर्ज हो गया। आपका भरोसा उनकी पहचान बनाता है।`,
            )}
          </Text>
          <PressScale
            onPress={onClose}
            style={[styles.doneBtn, { backgroundColor: accent, shadowColor: accent }]}
          >
            <Text style={styles.doneBtnText}>{t('Done', 'हो गया')}</Text>
          </PressScale>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.root} edges={['bottom']}>
      <StatusBar style="dark" />
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.scrollContent}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        {/* Drag handle */}
        <View style={styles.dragHandle} />

        {/* Header: VOUCH + ring */}
        <View style={styles.header}>
          <VouchScoreRing score={worker?.vouchScore ?? 0} size={64} accent={accent} />
          <View style={styles.headerText}>
            <Text style={styles.headerTitle}>{t('VOUCH', 'वाउच')}</Text>
            <Text style={styles.workerName}>{worker?.name ?? '—'}</Text>
            <Text style={styles.workerTrade}>{worker?.trade ?? ''}</Text>
          </View>
        </View>

        {/* Relationship section */}
        <Text style={styles.sectionLabel}>{t('Your relationship', 'आपका रिश्ता')}</Text>
        <View style={styles.chipsRow}>
          {RELATIONSHIPS.map((rel, i) => {
            const selected = selectedRelationship === i;
            return (
              <TouchableOpacity
                key={i}
                onPress={() => setSelectedRelationship(i)}
                style={[
                  styles.chip,
                  selected
                    ? { backgroundColor: accent }
                    : { backgroundColor: Colors.soft },
                ]}
                activeOpacity={0.75}
              >
                <Text style={[styles.chipText, { color: selected ? '#fff' : Colors.shadowGrey }]}>
                  {t(rel.en, rel.hi, rel)}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>

        {/* Star rating section */}
        <Text style={styles.sectionLabel}>{t('Rate their work', 'उनके काम को रेट करें')}</Text>
        <View style={styles.starsRow}>
          {[1, 2, 3, 4, 5].map(star => (
            <TouchableOpacity
              key={star}
              onPress={() => setStarRating(star)}
              activeOpacity={0.75}
              style={styles.starBtn}
            >
              <AppIcon
                name={star <= starRating ? Icons.starFill : Icons.star}
                size={32}
                color={star <= starRating ? accent : Colors.dimText}
              />
            </TouchableOpacity>
          ))}
        </View>

        {/* Note input */}
        <Text style={styles.sectionLabel}>{t('Short note · optional', 'छोटा नोट · वैकल्पिक')}</Text>
        <TextInput
          style={styles.noteInput}
          value={note}
          onChangeText={setNote}
          multiline
          numberOfLines={3}
          placeholder={t(
            'e.g. Fixed our wiring in one day, very professional…',
            'जैसे: एक दिन में वायरिंग ठीक की, बहुत पेशेवर…',
          )}
          placeholderTextColor={Colors.dimText}
          textAlignVertical="top"
        />

        {/* Submit button */}
        <PressScale
          onPress={handleSubmit}
          disabled={!canSubmit || submitting}
          style={[
            styles.submitBtn,
            { backgroundColor: accent, shadowColor: accent },
            (!canSubmit || submitting) && styles.submitBtnDisabled,
          ]}
        >
          {submitting ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.submitBtnText}>{t('Submit Vouch', 'वाउच सबमिट करें')}</Text>
          )}
        </PressScale>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.canvas },
  scroll: { flex: 1 },
  scrollContent: { paddingHorizontal: Spacing.lg, paddingBottom: 40 },

  dragHandle: {
    width: 32,
    height: 4,
    borderRadius: 2,
    backgroundColor: Colors.soft,
    alignSelf: 'center',
    marginTop: 12,
    marginBottom: 20,
  },

  // Header
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
    marginBottom: 28,
    backgroundColor: Colors.white,
    borderRadius: Radius.lg,
    padding: 16,
    ...Shadow.card,
  },
  headerText: { flex: 1 },
  headerTitle: {
    fontSize: 11,
    fontWeight: '800',
    color: Colors.dimText,
    letterSpacing: 1.5,
    textTransform: 'uppercase',
    marginBottom: 2,
  },
  workerName: { fontSize: 18, fontWeight: '800', color: Colors.shadowGrey },
  workerTrade: { fontSize: 13, color: Colors.mutedText, marginTop: 2 },

  // Section labels
  sectionLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: Colors.dimText,
    letterSpacing: 1,
    textTransform: 'uppercase',
    marginBottom: 10,
    marginTop: 4,
  },

  // Chips
  chipsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 22 },
  chip: {
    paddingVertical: 9,
    paddingHorizontal: 14,
    borderRadius: Radius.full,
  },
  chipText: { fontSize: 13, fontWeight: '600' },

  // Stars
  starsRow: { flexDirection: 'row', gap: 4, marginBottom: 22 },
  starBtn: { padding: 4 },
  star: { fontSize: 34 },

  // Note
  noteInput: {
    backgroundColor: Colors.soft,
    borderRadius: Radius.lg,
    padding: 14,
    fontSize: 15,
    color: Colors.shadowGrey,
    minHeight: 80,
    marginBottom: 28,
  },

  // Submit
  submitBtn: {
    paddingVertical: 16,
    borderRadius: Radius.lg,
    alignItems: 'center',
    ...Shadow.button,
  },
  submitBtnDisabled: { opacity: 0.4 },
  submitBtnText: { color: '#fff', fontSize: 16, fontWeight: '700' },

  // Success
  successContent: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: Spacing.lg,
    paddingBottom: 40,
  },
  checkCircle: {
    width: 80,
    height: 80,
    borderRadius: 40,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 20,
  },
  checkIcon: { fontSize: 36, color: '#fff', fontWeight: '700' },
  successTitle: {
    fontSize: 28,
    fontWeight: '800',
    color: Colors.shadowGrey,
    marginBottom: 12,
    letterSpacing: -0.5,
  },
  successBody: {
    fontSize: 15,
    color: Colors.mutedText,
    textAlign: 'center',
    lineHeight: 22,
    marginBottom: 36,
    maxWidth: 300,
  },
  doneBtn: {
    width: '100%',
    paddingVertical: 16,
    borderRadius: Radius.lg,
    alignItems: 'center',
    ...Shadow.button,
  },
  doneBtnText: { color: '#fff', fontSize: 16, fontWeight: '700' },
});
