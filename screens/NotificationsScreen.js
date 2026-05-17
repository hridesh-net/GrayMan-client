import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';

import { useTheme } from '../src/AppTheme';
import PressScale from '../src/components/PressScale';
import { workerService } from '../src/api/workerService';
import { Colors, Shadow } from '../src/theme';

export default function NotificationsScreen({ onClose }) {
  const { accent, t } = useTheme();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await workerService.fetchNotifications(true, 50);
      setItems(res?.notifications ?? res ?? []);
    } catch (e) {
      Alert.alert('Error', e.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const accept = async id => {
    try {
      await workerService.acceptNotification(id);
      await load();
    } catch (e) {
      Alert.alert('Error', e.message);
    }
  };

  const reject = async id => {
    try {
      await workerService.rejectNotification(id);
      await load();
    } catch (e) {
      Alert.alert('Error', e.message);
    }
  };

  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <StatusBar style="dark" />
      <View style={styles.header}>
        <PressScale onPress={onClose} style={styles.closeBtn}>
          <Text style={styles.closeBtnText}>✕</Text>
        </PressScale>
        <Text style={styles.title}>{t('Notifications', 'सूचनाएं')}</Text>
        <View style={{ width: 36 }} />
      </View>

      {loading ? (
        <ActivityIndicator style={{ marginTop: 40 }} color={accent} />
      ) : (
        <ScrollView contentContainerStyle={styles.list}>
          {items.length === 0 ? (
            <Text style={styles.empty}>{t('No pending items', 'कोई लंबित आइटम नहीं')}</Text>
          ) : (
            items.map(n => (
              <View key={n.id} style={[styles.card, Shadow.card]}>
                <Text style={styles.kind}>{n.kind}</Text>
                <Text style={styles.body}>
                  {n.payload?.extracted_trade || n.payload?.message || t('Reel analysis ready', 'रील विश्लेषण तैयार')}
                </Text>
                {n.kind === 'reel_analysis_ready' && (
                  <View style={styles.row}>
                    <PressScale onPress={() => accept(n.id)} style={[styles.btn, { backgroundColor: accent }]}>
                      <Text style={styles.btnText}>{t('Accept', 'स्वीकार')}</Text>
                    </PressScale>
                    <PressScale onPress={() => reject(n.id)} style={styles.btnOutline}>
                      <Text style={[styles.btnText, { color: Colors.shadowGrey }]}>{t('Reject', 'अस्वीकार')}</Text>
                    </PressScale>
                  </View>
                )}
              </View>
            ))
          )}
        </ScrollView>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.canvas },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 20, paddingVertical: 12 },
  closeBtn: { width: 36, height: 36, borderRadius: 12, backgroundColor: Colors.soft, alignItems: 'center', justifyContent: 'center' },
  closeBtnText: { fontSize: 16, fontWeight: '700', color: Colors.shadowGrey },
  title: { fontSize: 18, fontWeight: '800', color: Colors.shadowGrey },
  list: { padding: 20, gap: 12 },
  empty: { textAlign: 'center', color: Colors.mutedText, marginTop: 40 },
  card: { backgroundColor: Colors.white, borderRadius: 16, padding: 16, marginBottom: 12 },
  kind: { fontSize: 11, fontWeight: '700', color: Colors.dimText, letterSpacing: 0.5, marginBottom: 6 },
  body: { fontSize: 15, color: Colors.shadowGrey, marginBottom: 12 },
  row: { flexDirection: 'row', gap: 10 },
  btn: { flex: 1, paddingVertical: 12, borderRadius: 12, alignItems: 'center' },
  btnOutline: { flex: 1, paddingVertical: 12, borderRadius: 12, alignItems: 'center', backgroundColor: Colors.soft },
  btnText: { color: '#fff', fontWeight: '700', fontSize: 14 },
});
