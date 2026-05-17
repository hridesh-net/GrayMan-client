import React, { useState } from 'react';
import { ActivityIndicator } from 'react-native';
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
import { workerService } from '../src/api/workerService';
import { Colors } from '../src/theme';

export default function NameEntryScreen({ goBack, goNext }) {
  const { accent, t } = useTheme();
  const [name, setName] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const submit = async () => {
    if (!isValid || loading) return;
    setLoading(true);
    setError(null);
    try {
      await workerService.updateSelf({ name: trimmed });
      goNext(trimmed);
    } catch (e) {
      setError(e.message || 'Could not save name');
    } finally {
      setLoading(false);
    }
  };

  const trimmed = name.trim();
  const isValid = trimmed.length > 1;
  const firstName = trimmed.split(' ')[0];

  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <StatusBar style="dark" />
      <Blobs accent={accent} opacity={0.6} />

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
          <View style={styles.headlineGroup}>
            <Text style={styles.heading}>
              {t("What should\nwe call you?", "आपको क्या\nबुलाएं?")}
            </Text>
            <Text style={styles.subtext}>
              {t(
                'This will appear on your work profile',
                'यह आपकी वर्क प्रोफ़ाइल पर दिखेगा',
              )}
            </Text>
          </View>

          <View style={{ paddingHorizontal: 28 }}>
            <View style={[styles.inputWrapper, isValid && { borderColor: accent }]}>
              <TextInput
                style={styles.nameInput}
                value={name}
                onChangeText={setName}
                placeholder={t('Your full name', 'आपका पूरा नाम')}
                placeholderTextColor={Colors.dimText}
                autoFocus
                autoCapitalize="words"
                returnKeyType="done"
                onSubmitEditing={submit}
              />
            </View>

            {isValid && (
              <View style={styles.feedbackRow}>
                <View style={[styles.feedbackDot, { backgroundColor: accent }]} />
                <Text style={[styles.feedbackText, { color: accent }]}>
                  {t(`Looks great, ${firstName}!`, `बहुत अच्छा, ${firstName}!`)}
                </Text>
              </View>
            )}
            {error ? <Text style={styles.errorText}>{error}</Text> : null}
          </View>
        </View>

        <View style={styles.bottomSection}>
          <PressScale
            onPress={submit}
            disabled={!isValid || loading}
            style={[
              styles.continueBtn,
              { backgroundColor: isValid ? accent : Colors.soft },
              isValid && { shadowColor: accent, shadowOffset: { width: 0, height: 6 }, shadowOpacity: 0.36, shadowRadius: 12 },
            ]}
          >
            {loading ? (
              <ActivityIndicator color={isValid ? '#fff' : Colors.dimText} />
            ) : (
              <Text style={[styles.continueBtnText, { color: isValid ? '#fff' : Colors.dimText }]}>
                {t('Continue', 'जारी रखें')}
              </Text>
            )}
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
    paddingHorizontal: 22,
    paddingTop: 8,
  },
  backBtn: {
    width: 40,
    height: 40,
    borderRadius: 14,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  backArrow: {
    fontSize: 16,
    color: Colors.shadowGrey,
    fontWeight: 'bold',
  },
  content: {
    flex: 1,
  },
  headlineGroup: {
    paddingHorizontal: 28,
    paddingTop: 40,
    paddingBottom: 40,
  },
  heading: {
    fontSize: 32,
    fontWeight: '900',
    color: Colors.shadowGrey,
    letterSpacing: -1.3,
    lineHeight: 38,
    marginBottom: 8,
  },
  subtext: {
    fontSize: 15,
    color: Colors.mutedText,
  },
  inputWrapper: {
    backgroundColor: Colors.soft,
    borderRadius: 18,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  nameInput: {
    fontSize: 18,
    fontWeight: '600',
    color: Colors.shadowGrey,
    paddingHorizontal: 20,
    paddingVertical: 18,
  },
  feedbackRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 12,
    gap: 8,
  },
  feedbackDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  feedbackText: {
    fontSize: 13,
    fontWeight: '600',
  },
  errorText: {
    fontSize: 13,
    color: '#E63946',
    marginTop: 12,
    fontWeight: '600',
  },
  bottomSection: {
    paddingHorizontal: 24,
    paddingBottom: 32,
  },
  continueBtn: {
    paddingVertical: 17,
    borderRadius: 16,
    alignItems: 'center',
  },
  continueBtnText: {
    fontSize: 16,
    fontWeight: 'bold',
  },
});
