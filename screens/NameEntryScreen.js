import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';

import { useTheme } from '../src/AppTheme';
import Blobs from '../src/components/Blobs';
import PressScale from '../src/components/PressScale';
import { Colors, Shadow } from '../src/theme';

export default function NameEntryScreen({ goBack, goNext }) {
  const { accent, t } = useTheme();
  const [name, setName] = useState('');

  const trimmed = name.trim();
  const isValid = trimmed.length > 1;
  const firstName = trimmed.split(' ')[0];

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

      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        keyboardVerticalOffset={0}
      >
        <View style={styles.content}>
          {/* Heading */}
          <Text style={styles.heading}>
            {t("What should\nwe call you?", "आपको क्या\nबुलाएं?")}
          </Text>

          {/* Subtext */}
          <Text style={styles.subtext}>
            {t(
              'This will appear on your work profile',
              'यह आपकी वर्क प्रोफ़ाइल पर दिखेगा',
            )}
          </Text>

          {/* Name input */}
          <TextInput
            style={styles.nameInput}
            value={name}
            onChangeText={setName}
            placeholder={t('Your full name', 'आपका पूरा नाम')}
            placeholderTextColor={Colors.dimText}
            autoFocus
            autoCapitalize="words"
            returnKeyType="done"
            onSubmitEditing={() => isValid && goNext(trimmed)}
          />

          {/* Feedback */}
          {isValid && (
            <Text style={[styles.feedbackText, { color: accent }]}>
              {`✓ ${t('Looks great', 'बढ़िया है')}, ${firstName}!`}
            </Text>
          )}
        </View>

        {/* Bottom CTA */}
        <View style={styles.bottomSection}>
          <PressScale
            onPress={() => isValid && goNext(trimmed)}
            disabled={!isValid}
            style={[
              styles.continueBtn,
              { backgroundColor: accent, shadowColor: accent },
              !isValid && styles.continueBtnDisabled,
            ]}
          >
            <Text style={styles.continueBtnText}>
              {t('Continue', 'जारी रखें')}
            </Text>
          </PressScale>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: Colors.canvas,
  },
  flex: {
    flex: 1,
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
  heading: {
    fontSize: 34,
    fontWeight: '800',
    color: Colors.shadowGrey,
    lineHeight: 42,
    marginBottom: 10,
  },
  subtext: {
    fontSize: 15,
    color: Colors.mutedText,
    marginBottom: 28,
  },
  nameInput: {
    fontSize: 18,
    fontWeight: '500',
    color: Colors.shadowGrey,
    backgroundColor: Colors.soft,
    borderRadius: 16,
    paddingHorizontal: 18,
    paddingVertical: 16,
    marginBottom: 12,
  },
  feedbackText: {
    fontSize: 14,
    fontWeight: '600',
    marginTop: 2,
  },
  bottomSection: {
    paddingHorizontal: 24,
    paddingBottom: 24,
  },
  continueBtn: {
    paddingVertical: 17,
    borderRadius: 16,
    alignItems: 'center',
    ...Shadow.button,
  },
  continueBtnDisabled: {
    opacity: 0.4,
  },
  continueBtnText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
  },
});
