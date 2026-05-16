import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Modal,
  TextInput,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';

import { useTheme } from '../src/AppTheme';
import PressScale from '../src/components/PressScale';
import { Colors, Spacing, Radius, Shadow } from '../src/theme';

function formatDate(date) {
  return date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
}

export default function ProofOfWorkScreen({ onClose }) {
  const { accent, t } = useTheme();

  const [sessions, setSessions] = useState([]);
  const [showAddSheet, setShowAddSheet] = useState(false);
  const [newCaption, setNewCaption] = useState('');

  const handleSaveProgress = () => {
    if (!newCaption.trim()) return;
    const session = {
      id: Date.now().toString(),
      date: formatDate(new Date()),
      caption: newCaption.trim(),
      hasPhoto: false,
    };
    setSessions(prev => [...prev, session]);
    setNewCaption('');
    setShowAddSheet(false);
  };

  const handleCloseSheet = () => {
    setNewCaption('');
    setShowAddSheet(false);
  };

  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <StatusBar style="dark" />

      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={onClose} style={styles.closeBtn} activeOpacity={0.8}>
          <Text style={styles.closeBtnText}>✕</Text>
        </TouchableOpacity>
        <Text style={styles.heading}>{t('Proof of Work', 'काम का सबूत')}</Text>
      </View>

      {/* Sub-tag + description */}
      <View style={styles.descSection}>
        <View style={[styles.subTag, { backgroundColor: accent + '22' }]}>
          <Text style={[styles.subTagText, { color: accent }]}>
            {t('Day 1 → Done', 'दिन 1 → पूरा')}
          </Text>
        </View>
        <Text style={styles.descBody}>
          {t(
            'Document your work day-by-day. We compile your photos into a time-lapse reel that shows clients the quality of your craft.',
            'अपना काम दिन-दर-दिन दर्ज करें। हम आपकी फ़ोटो को एक टाइम-लैप्स रील में बदलते हैं जो क्लाइंट को आपके काम की गुणवत्ता दिखाती है।',
          )}
        </Text>
      </View>

      {/* Session list */}
      <ScrollView
        style={styles.list}
        contentContainerStyle={styles.listContent}
        showsVerticalScrollIndicator={false}
      >
        {sessions.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={styles.emptyEmoji}>📸</Text>
            <Text style={styles.emptyTitle}>{t('No sessions yet', 'अभी कोई सेशन नहीं')}</Text>
            <Text style={styles.emptyBody}>
              {t(
                'Tap "Add Today's Progress" to log your first day on the job.',
                '"आज की प्रगति जोड़ें" टैप करें और अपना पहला दिन दर्ज करें।',
              )}
            </Text>
          </View>
        ) : (
          sessions.map((session, index) => (
            <View key={session.id} style={styles.sessionCard}>
              {/* Photo placeholder */}
              <View style={styles.photoPlaceholder}>
                <Text style={styles.photoIcon}>📷</Text>
                <Text style={styles.photoLabel}>{t('Photo', 'फ़ोटो')}</Text>
              </View>
              <View style={styles.sessionInfo}>
                <Text style={styles.sessionDay}>
                  {t(`Day ${index + 1}`, `दिन ${index + 1}`)}
                </Text>
                <Text style={styles.sessionCaption} numberOfLines={2}>
                  {session.caption}
                </Text>
                <View style={[styles.dateBadge, { backgroundColor: Colors.soft }]}>
                  <Text style={styles.dateText}>{session.date}</Text>
                </View>
              </View>
            </View>
          ))
        )}
      </ScrollView>

      {/* Bottom actions */}
      <View style={styles.bottomActions}>
        <PressScale
          onPress={() => setShowAddSheet(true)}
          style={[styles.addBtn, { backgroundColor: accent, shadowColor: accent }]}
        >
          <Text style={styles.addBtnText}>
            + {t("Add Today's Progress", 'आज की प्रगति जोड़ें')}
          </Text>
        </PressScale>

        {sessions.length >= 2 && (
          <PressScale
            onPress={() => {}}
            style={[styles.reelBtn, { borderColor: accent }]}
          >
            <Text style={[styles.reelBtnText, { color: accent }]}>
              🎬 {t('Compile Time-Lapse Reel', 'टाइम-लैप्स रील बनाएं')}
            </Text>
          </PressScale>
        )}
      </View>

      {/* Add progress sheet modal */}
      <Modal
        visible={showAddSheet}
        animationType="slide"
        transparent
        onRequestClose={handleCloseSheet}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalSheet}>
            {/* Handle */}
            <View style={styles.dragHandle} />

            <Text style={styles.modalTitle}>
              {t(`Day ${sessions.length + 1}`, `दिन ${sessions.length + 1}`)}
            </Text>

            {/* Photo tap area */}
            <TouchableOpacity style={styles.modalPhotoArea} activeOpacity={0.75}>
              <Text style={styles.modalPhotoIcon}>📷</Text>
              <Text style={styles.modalPhotoLabel}>{t('Tap to add photo', 'फ़ोटो जोड़ने के लिए टैप करें')}</Text>
            </TouchableOpacity>

            {/* Caption input */}
            <TextInput
              style={styles.captionInput}
              value={newCaption}
              onChangeText={setNewCaption}
              placeholder={t("What did you complete today?", 'आज आपने क्या पूरा किया?')}
              placeholderTextColor={Colors.dimText}
              multiline
              numberOfLines={3}
              textAlignVertical="top"
            />

            {/* Save button */}
            <PressScale
              onPress={handleSaveProgress}
              disabled={!newCaption.trim()}
              style={[
                styles.saveBtn,
                { backgroundColor: accent, shadowColor: accent },
                !newCaption.trim() && { opacity: 0.4 },
              ]}
            >
              <Text style={styles.saveBtnText}>{t('Save Progress', 'प्रगति सेव करें')}</Text>
            </PressScale>

            <TouchableOpacity onPress={handleCloseSheet} style={styles.cancelBtn} activeOpacity={0.7}>
              <Text style={styles.cancelBtnText}>{t('Cancel', 'रद्द करें')}</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.canvas },

  // Header
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.lg,
    paddingTop: 8,
    paddingBottom: 4,
    gap: 12,
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
  heading: {
    fontSize: 24,
    fontWeight: '800',
    color: Colors.shadowGrey,
    letterSpacing: -0.5,
  },

  // Description
  descSection: { paddingHorizontal: Spacing.lg, marginBottom: 16, marginTop: 10 },
  subTag: {
    alignSelf: 'flex-start',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: Radius.full,
    marginBottom: 8,
  },
  subTagText: { fontSize: 12, fontWeight: '700' },
  descBody: { fontSize: 14, color: Colors.mutedText, lineHeight: 20 },

  // Session list
  list: { flex: 1 },
  listContent: { paddingHorizontal: Spacing.lg, paddingBottom: 16, gap: 12 },

  // Empty state
  emptyState: {
    alignItems: 'center',
    paddingTop: 40,
    paddingHorizontal: 20,
  },
  emptyEmoji: { fontSize: 52, marginBottom: 16 },
  emptyTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: Colors.shadowGrey,
    marginBottom: 8,
  },
  emptyBody: {
    fontSize: 14,
    color: Colors.mutedText,
    textAlign: 'center',
    lineHeight: 20,
  },

  // Session card
  sessionCard: {
    flexDirection: 'row',
    backgroundColor: Colors.white,
    borderRadius: Radius.lg,
    padding: 14,
    gap: 14,
    alignItems: 'center',
    ...Shadow.card,
  },
  photoPlaceholder: {
    width: 80,
    height: 80,
    borderRadius: Radius.md,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
  },
  photoIcon: { fontSize: 24 },
  photoLabel: { fontSize: 11, color: Colors.dimText, fontWeight: '500' },
  sessionInfo: { flex: 1, gap: 4 },
  sessionDay: { fontSize: 11, fontWeight: '700', color: Colors.dimText, letterSpacing: 0.5 },
  sessionCaption: { fontSize: 14, color: Colors.shadowGrey, lineHeight: 20 },
  dateBadge: {
    alignSelf: 'flex-start',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: Radius.sm,
    marginTop: 2,
  },
  dateText: { fontSize: 12, color: Colors.dimText, fontWeight: '500' },

  // Bottom actions
  bottomActions: {
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.lg,
    paddingTop: 10,
    gap: 10,
  },
  addBtn: {
    paddingVertical: 15,
    borderRadius: Radius.lg,
    alignItems: 'center',
    ...Shadow.button,
  },
  addBtnText: { color: '#fff', fontSize: 15, fontWeight: '700' },
  reelBtn: {
    paddingVertical: 14,
    borderRadius: Radius.lg,
    alignItems: 'center',
    borderWidth: 1.5,
    backgroundColor: 'transparent',
  },
  reelBtnText: { fontSize: 15, fontWeight: '700' },

  // Add sheet modal
  modalOverlay: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: 'rgba(0,0,0,0.35)',
  },
  modalSheet: {
    backgroundColor: Colors.canvas,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    paddingHorizontal: Spacing.lg,
    paddingBottom: 36,
  },
  dragHandle: {
    width: 32,
    height: 4,
    borderRadius: 2,
    backgroundColor: Colors.soft,
    alignSelf: 'center',
    marginTop: 12,
    marginBottom: 20,
  },
  modalTitle: {
    fontSize: 22,
    fontWeight: '800',
    color: Colors.shadowGrey,
    marginBottom: 18,
    letterSpacing: -0.3,
  },
  modalPhotoArea: {
    height: 120,
    width: 120,
    borderRadius: Radius.lg,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 18,
    gap: 6,
    alignSelf: 'center',
  },
  modalPhotoIcon: { fontSize: 32 },
  modalPhotoLabel: { fontSize: 12, color: Colors.mutedText, fontWeight: '500' },
  captionInput: {
    backgroundColor: Colors.soft,
    borderRadius: Radius.lg,
    padding: 14,
    fontSize: 15,
    color: Colors.shadowGrey,
    minHeight: 80,
    marginBottom: 20,
  },
  saveBtn: {
    paddingVertical: 15,
    borderRadius: Radius.lg,
    alignItems: 'center',
    ...Shadow.button,
    marginBottom: 10,
  },
  saveBtnText: { color: '#fff', fontSize: 15, fontWeight: '700' },
  cancelBtn: { alignItems: 'center', paddingVertical: 8 },
  cancelBtnText: { fontSize: 15, color: Colors.mutedText, fontWeight: '500' },
});
