import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import PressScale from './PressScale';
import { Colors, Radius, Spacing } from '../theme';

/**
 * In-screen dialog overlay. Use instead of Alert.alert when the screen
 * is presented inside a React Native Modal (Alert.alert is broken on Android).
 */
export default function AppDialog({
  visible,
  title,
  message,
  buttons,
  accent = Colors.shadowGrey,
  onDismiss,
}) {
  if (!visible) return null;

  const resolvedButtons = buttons?.length
    ? buttons
    : [{ text: 'OK', onPress: onDismiss }];

  return (
    <View style={styles.overlay} pointerEvents="box-none">
      <View style={styles.box}>
        {!!title && <Text style={styles.title}>{title}</Text>}
        {!!message && <Text style={styles.message}>{message}</Text>}
        <View style={resolvedButtons.length > 2 ? styles.actionsStack : styles.actionsRow}>
          {resolvedButtons.map((btn, index) => {
            const isCancel = btn.style === 'cancel';
            const isPrimary = resolvedButtons.length === 1 && !isCancel;
            return (
              <PressScale
                key={`${btn.text}-${index}`}
                onPress={() => {
                  btn.onPress?.();
                  if (!btn.keepOpen) onDismiss?.();
                }}
                style={[
                  styles.btn,
                  isCancel && styles.btnCancel,
                  isPrimary && { backgroundColor: accent },
                  resolvedButtons.length > 2 && styles.btnStacked,
                ]}
              >
                <Text
                  style={[
                    styles.btnText,
                    isCancel && styles.btnCancelText,
                    isPrimary && styles.btnPrimaryText,
                  ]}
                >
                  {btn.text}
                </Text>
              </PressScale>
            );
          })}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.45)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: Spacing.lg,
    zIndex: 1000,
    elevation: 1000,
  },
  box: {
    width: '100%',
    maxWidth: 340,
    backgroundColor: Colors.canvas,
    borderRadius: Radius.lg,
    padding: Spacing.lg,
    gap: 12,
  },
  title: {
    fontSize: 18,
    fontWeight: '800',
    color: Colors.shadowGrey,
    textAlign: 'center',
  },
  message: {
    fontSize: 14,
    color: Colors.mutedText,
    lineHeight: 20,
    textAlign: 'center',
  },
  actionsRow: {
    flexDirection: 'row',
    gap: 10,
    marginTop: 4,
  },
  actionsStack: {
    gap: 8,
    marginTop: 4,
  },
  btn: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: Radius.md,
    alignItems: 'center',
    backgroundColor: Colors.soft,
  },
  btnStacked: {
    flex: 0,
    width: '100%',
  },
  btnCancel: {
    backgroundColor: 'transparent',
  },
  btnText: {
    fontSize: 15,
    fontWeight: '700',
    color: Colors.shadowGrey,
  },
  btnCancelText: {
    color: Colors.mutedText,
    fontWeight: '600',
  },
  btnPrimaryText: {
    color: '#fff',
  },
});
