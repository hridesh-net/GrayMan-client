import React, { useState, useEffect, useCallback } from 'react';
import {
  ActivityIndicator,
  Image,
  Platform,
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
import * as ImagePicker from 'expo-image-picker';

import { useTheme } from '../src/AppTheme';
import { dayLabel, tpl } from '../src/i18n';
import PressScale from '../src/components/PressScale';
import { apiErrorMessage } from '../src/api/apiClient';
import { workerService } from '../src/api/workerService';
import { compileTimelapse } from '../src/services/timelapseCompile';
import { Colors, Spacing, Radius, Shadow } from '../src/theme';
import AppIcon, { Icons, IconLabel } from '../src/components/AppIcon';
import AppDialog from '../src/components/AppDialog';
import { VideoView, useVideoPlayer } from 'expo-video';

const PICKER_OPTIONS = {
  mediaTypes: ['images'],
  quality: 0.8,
  allowsEditing: false,
};

function formatDate(date) {
  return date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
}

function mapPhotoItem(it) {
  return {
    id: it.id,
    kind: 'photo',
    date: it.captured_at
      ? new Date(it.captured_at).toLocaleDateString('en-IN')
      : '—',
    caption: it.title || it.description || '',
    photoUri: it.media_url || it.thumbnail_url || null,
    hasPhoto: !!(it.media_url || it.thumbnail_url),
  };
}

function mapTimelapseItem(it) {
  return {
    id: it.id,
    kind: 'time_lapse',
    title: it.title || '',
    description: it.description || '',
    mediaUrl: it.media_url,
    thumbnailUrl: it.thumbnail_url,
    durationSeconds: it.duration_seconds,
    date: it.created_at
      ? new Date(it.created_at).toLocaleDateString('en-IN')
      : '—',
  };
}

function TimelapseVideoCard({ mediaUrl }) {
  const source = { uri: mediaUrl };
  const player = useVideoPlayer(source, p => {
    p.loop = false;
    p.muted = false;
    p.play();
  });

  return (
    <VideoView
      style={styles.timelapseVideo}
      player={player}
      contentFit="cover"
      nativeControls
      allowsPictureInPicture={false}
    />
  );
}

export default function ProofOfWorkScreen({ workerId, onClose }) {
  const { accent, t } = useTheme();

  const [sessions, setSessions] = useState([]);
  const [timelapses, setTimelapses] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showAddSheet, setShowAddSheet] = useState(false);
  const [showCompileSheet, setShowCompileSheet] = useState(false);
  const [newCaption, setNewCaption] = useState('');
  const [compileTitle, setCompileTitle] = useState('');
  const [photoUri, setPhotoUri] = useState(null);
  const [saving, setSaving] = useState(false);
  const [compiling, setCompiling] = useState(false);
  const [compilePhase, setCompilePhase] = useState(null);
  const [dialog, setDialog] = useState(null);

  const showDialog = (title, message, buttons) => setDialog({ title, message, buttons });
  const hideDialog = () => setDialog(null);

  const photoCount = sessions.length;

  const loadShowcase = useCallback(async () => {
    if (!workerId) { setLoading(false); return; }
    try {
      const [photos, lapses] = await Promise.all([
        workerService.fetchShowcase(workerId, 'photo'),
        workerService.fetchShowcase(workerId, 'time_lapse'),
      ]);
      setSessions((photos || []).map(mapPhotoItem));
      setTimelapses((lapses || []).map(mapTimelapseItem));
    } catch (e) {
      showDialog(t('Error', 'त्रुटि'), apiErrorMessage(e));
    } finally {
      setLoading(false);
    }
  }, [workerId]);

  useEffect(() => {
    loadShowcase();
  }, [loadShowcase]);

  const applyPickedAsset = (asset) => {
    if (!asset?.uri) return;
    setPhotoUri(asset.uri);
  };

  const takePhoto = async () => {
    const perm = await ImagePicker.requestCameraPermissionsAsync();
    if (!perm.granted) {
      showDialog(
        t('Camera access needed', 'कैमरा अनुमति चाहिए'),
        t('Enable camera in Settings to add progress photos.', 'प्रगति फ़ोटो के लिए सेटिंग्स में कैमरा चालू करें।'),
      );
      return;
    }
    const result = await ImagePicker.launchCameraAsync(PICKER_OPTIONS);
    if (!result.canceled && result.assets?.[0]) {
      applyPickedAsset(result.assets[0]);
    }
  };

  const pickFromLibrary = async () => {
    const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!perm.granted) {
      showDialog(
        t('Photos access needed', 'फ़ोटो अनुमति चाहिए'),
        t('Enable photo library access in Settings.', 'सेटिंग्स में फ़ोटो लाइब्रेरी की अनुमति दें।'),
      );
      return;
    }
    const result = await ImagePicker.launchImageLibraryAsync(PICKER_OPTIONS);
    if (!result.canceled && result.assets?.[0]) {
      applyPickedAsset(result.assets[0]);
    }
  };

  /** Android image picker can fail while a transparent Modal is visible. */
  const runPicker = async (fn) => {
    if (Platform.OS === 'android' && showAddSheet) {
      setShowAddSheet(false);
      await new Promise(resolve => setTimeout(resolve, 300));
      await fn();
      setShowAddSheet(true);
      return;
    }
    await fn();
  };

  const openPhotoPicker = () => {
    showDialog(
      t('Add photo', 'फ़ोटो जोड़ें'),
      t('Take a new photo or choose from your gallery.', 'नई फ़ोटो लें या गैलरी से चुनें।'),
      [
        {
          text: t('Take photo', 'फ़ोटो लें'),
          onPress: () => { void runPicker(takePhoto); },
        },
        {
          text: t('Photo library', 'गैलरी'),
          onPress: () => { void runPicker(pickFromLibrary); },
        },
        { text: t('Cancel', 'रद्द करें'), style: 'cancel' },
      ],
    );
  };

  const handleSaveProgress = async () => {
    if (!newCaption.trim() || !photoUri || saving) return;

    setSaving(true);
    try {
      const presigned = await workerService.requestShowcaseUploadURL('photo', 'image/jpeg');
      const res = await fetch(photoUri);
      if (!res.ok) throw new Error('Could not read photo');
      const blob = await res.blob();
      await workerService.uploadToS3(presigned.upload_url, blob, 'image/jpeg');

      const item = await workerService.createShowcaseItem({
        kind: 'photo',
        title: newCaption.trim(),
        description: null,
        s3_key: presigned.key,
        thumbnail_url: null,
        duration_seconds: null,
        captured_at: new Date().toISOString(),
        position: sessions.length,
      });

      setSessions(prev => [mapPhotoItem({
        ...item,
        media_url: item.media_url || presigned.public_url,
      }), ...prev]);
      setNewCaption('');
      setPhotoUri(null);
      setShowAddSheet(false);
    } catch (e) {
      showDialog(
        t('Upload failed', 'अपलोड विफल'),
        apiErrorMessage(e) || t('Could not save progress. Try again.', 'प्रगति सेव नहीं हो सकी। फिर कोशिश करें।'),
      );
    } finally {
      setSaving(false);
    }
  };

  const handleCloseSheet = () => {
    setNewCaption('');
    setPhotoUri(null);
    setShowAddSheet(false);
  };

  const handleCompileTimeLapse = () => {
    if (photoCount < 2) {
      showDialog(
        t('Need more photos', 'और फ़ोटो चाहिए'),
        t('Add at least 2 progress photos before compiling a time-lapse.', 'टाइम-लैप्स बनाने से पहले कम से कम 2 प्रगति फ़ोटो जोड़ें।'),
      );
      return;
    }
    setCompileTitle(
      t('Site progress', 'साइट प्रगति') + ` — ${formatDate(new Date())}`,
    );
    setShowCompileSheet(true);
  };

  const handleStartCompile = async () => {
    if (!compileTitle.trim() || compiling) return;

    setShowCompileSheet(false);
    setCompiling(true);
    setCompilePhase('queued');

    try {
      await compileTimelapse({
        title: compileTitle.trim(),
        photoItemIds: [],
        frameDurationSeconds: 0.5,
        onStatus: (status) => setCompilePhase(status),
      });

      await loadShowcase();

      showDialog(
        t('Time-lapse ready', 'टाइम-लैप्स तैयार'),
        t(
          'Your time-lapse reel has been compiled. Scroll up to preview and share it with clients.',
          'आपकी टाइम-लैप्स रील बन गई है। ऊपर स्क्रॉल करके देखें और क्लाइंट्स के साथ शेयर करें।',
        ),
      );
    } catch (e) {
      showDialog(
        t('Compilation failed', 'कंपाइल विफल'),
        apiErrorMessage(e) || t('Could not build time-lapse. Try again.', 'टाइम-लैप्स नहीं बन सका। फिर कोशिश करें।'),
      );
    } finally {
      setCompiling(false);
      setCompilePhase(null);
    }
  };

  const compilePhaseLabel = () => {
    switch (compilePhase) {
      case 'queued':
        return t('Queued…', 'कतार में…');
      case 'processing':
        return t('Compiling video…', 'वीडियो बन रहा है…');
      default:
        return t('Starting…', 'शुरू हो रहा है…');
    }
  };

  const canSave = !!newCaption.trim() && !!photoUri && !saving;

  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <StatusBar style="dark" />

      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={onClose} style={styles.closeBtn} activeOpacity={0.8}>
          <AppIcon name={Icons.close} size={18} color={Colors.shadowGrey} />
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
        {loading ? (
          <ActivityIndicator color={accent} style={{ marginTop: 24 }} />
        ) : sessions.length === 0 && timelapses.length === 0 ? (
          <View style={styles.emptyState}>
            <AppIcon name={Icons.camera} size={52} color={Colors.dimText} style={{ marginBottom: 16 }} />
            <Text style={styles.emptyTitle}>{t('No sessions yet', 'अभी कोई सेशन नहीं')}</Text>
            <Text style={styles.emptyBody}>
              {t(
                'Tap "Add Today\'s Progress" to log your first day on the job.',
                '"आज की प्रगति जोड़ें" टैप करें और अपना पहला दिन दर्ज करें।',
              )}
            </Text>
          </View>
        ) : (
          <>
            {timelapses.map(item => (
              <View key={item.id} style={styles.timelapseCard}>
                {item.mediaUrl ? (
                  <TimelapseVideoCard mediaUrl={item.mediaUrl} />
                ) : item.thumbnailUrl ? (
                  <Image source={{ uri: item.thumbnailUrl }} style={styles.timelapseThumb} />
                ) : (
                  <View style={styles.timelapseThumbPlaceholder}>
                    <AppIcon name={Icons.film} size={32} color={Colors.dimText} />
                  </View>
                )}
                <View style={styles.sessionInfo}>
                  <View style={[styles.subTag, { backgroundColor: accent + '22', marginBottom: 4 }]}>
                    <Text style={[styles.subTagText, { color: accent }]}>
                      {t('Time-lapse', 'टाइम-लैप्स')}
                    </Text>
                  </View>
                  <Text style={styles.sessionCaption} numberOfLines={2}>{item.title}</Text>
                  {item.description ? (
                    <Text style={styles.timelapseDesc} numberOfLines={2}>{item.description}</Text>
                  ) : null}
                  <View style={[styles.dateBadge, { backgroundColor: Colors.soft }]}>
                    <Text style={styles.dateText}>
                      {item.durationSeconds != null
                        ? `${Number(item.durationSeconds).toFixed(1)}s · ${item.date}`
                        : item.date}
                    </Text>
                  </View>
                </View>
              </View>
            ))}
            {sessions.map((session, index) => (
              <View key={session.id} style={styles.sessionCard}>
                {session.photoUri ? (
                  <Image source={{ uri: session.photoUri }} style={styles.photoThumb} />
                ) : (
                  <View style={styles.photoPlaceholder}>
                    <AppIcon name={Icons.camera} size={28} color={Colors.dimText} />
                    <Text style={styles.photoLabel}>{t('Photo', 'फ़ोटो')}</Text>
                  </View>
                )}
                <View style={styles.sessionInfo}>
                  <Text style={styles.sessionDay}>
                    {dayLabel(t, index + 1)}
                  </Text>
                  <Text style={styles.sessionCaption} numberOfLines={2}>
                    {session.caption}
                  </Text>
                  <View style={[styles.dateBadge, { backgroundColor: Colors.soft }]}>
                    <Text style={styles.dateText}>{session.date}</Text>
                  </View>
                </View>
              </View>
            ))}
          </>
        )}
      </ScrollView>

      {/* Bottom actions */}
      <View style={styles.bottomActions}>
        <PressScale
          onPress={() => setShowAddSheet(true)}
          disabled={compiling}
          style={[styles.addBtn, { backgroundColor: accent, shadowColor: accent }, compiling && { opacity: 0.5 }]}
        >
          <Text style={styles.addBtnText}>
            + {t("Add Today's Progress", 'आज की प्रगति जोड़ें')}
          </Text>
        </PressScale>

        {photoCount >= 2 && (
          <PressScale
            onPress={handleCompileTimeLapse}
            disabled={compiling}
            style={[styles.reelBtn, { borderColor: accent }, compiling && { opacity: 0.5 }]}
          >
            {compiling ? (
              <ActivityIndicator color={accent} />
            ) : (
              <IconLabel icon={Icons.film} size={18} color={accent} textStyle={[styles.reelBtnText, { color: accent }]}>
                {t('Compile Time-Lapse Reel', 'टाइम-लैप्स रील बनाएं')}
              </IconLabel>
            )}
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
              {dayLabel(t, sessions.length + 1)}
            </Text>

            {/* Photo tap area */}
            <TouchableOpacity
              style={styles.modalPhotoArea}
              activeOpacity={0.75}
              onPress={openPhotoPicker}
            >
              {photoUri ? (
                <Image source={{ uri: photoUri }} style={styles.modalPhotoPreview} />
              ) : (
                <>
                  <AppIcon name={Icons.camera} size={32} color={Colors.mutedText} />
                  <Text style={styles.modalPhotoLabel}>
                    {t('Tap to add photo', 'फ़ोटो जोड़ने के लिए टैप करें')}
                  </Text>
                </>
              )}
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
              disabled={!canSave}
              style={[
                styles.saveBtn,
                { backgroundColor: accent, shadowColor: accent },
                !canSave && { opacity: 0.4 },
              ]}
            >
              {saving ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <Text style={styles.saveBtnText}>{t('Save Progress', 'प्रगति सेव करें')}</Text>
              )}
            </PressScale>

            <TouchableOpacity onPress={handleCloseSheet} style={styles.cancelBtn} activeOpacity={0.7}>
              <Text style={styles.cancelBtnText}>{t('Cancel', 'रद्द करें')}</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* Compile title sheet */}
      <Modal
        visible={showCompileSheet}
        animationType="slide"
        transparent
        onRequestClose={() => setShowCompileSheet(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalSheet}>
            <View style={styles.dragHandle} />
            <Text style={styles.modalTitle}>
              {t('Compile Time-Lapse', 'टाइम-लैप्स बनाएं')}
            </Text>
            <Text style={styles.compileHint}>
              {tpl(
                t,
                'Uses all {count} photos, ordered by date.',
                'सभी {count} फ़ोटो का उपयोग, तारीख के क्रम में।',
                { count: photoCount },
              )}
            </Text>
            <TextInput
              style={styles.captionInput}
              value={compileTitle}
              onChangeText={setCompileTitle}
              placeholder={t('Reel title', 'रील शीर्षक')}
              placeholderTextColor={Colors.dimText}
            />
            <PressScale
              onPress={handleStartCompile}
              disabled={!compileTitle.trim()}
              style={[
                styles.saveBtn,
                { backgroundColor: accent, shadowColor: accent },
                !compileTitle.trim() && { opacity: 0.4 },
              ]}
            >
              <Text style={styles.saveBtnText}>{t('Start compile', 'कंपाइल शुरू करें')}</Text>
            </PressScale>
            <TouchableOpacity
              onPress={() => setShowCompileSheet(false)}
              style={styles.cancelBtn}
              activeOpacity={0.7}
            >
              <Text style={styles.cancelBtnText}>{t('Cancel', 'रद्द करें')}</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {compiling && (
        <View style={styles.compileOverlay}>
          <ActivityIndicator size="large" color={accent} />
          <Text style={styles.compileOverlayText}>{compilePhaseLabel()}</Text>
        </View>
      )}

      <AppDialog
        visible={!!dialog}
        title={dialog?.title}
        message={dialog?.message}
        buttons={dialog?.buttons}
        accent={accent}
        onDismiss={hideDialog}
      />
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

  timelapseCard: {
    backgroundColor: Colors.white,
    borderRadius: Radius.lg,
    padding: 14,
    gap: 12,
    ...Shadow.card,
  },
  timelapseVideo: {
    width: '100%',
    height: 200,
    borderRadius: Radius.md,
    backgroundColor: '#000',
  },
  timelapseThumb: {
    width: '100%',
    height: 200,
    borderRadius: Radius.md,
    backgroundColor: Colors.soft,
  },
  timelapseThumbPlaceholder: {
    width: '100%',
    height: 120,
    borderRadius: Radius.md,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  timelapseDesc: {
    fontSize: 13,
    color: Colors.mutedText,
    lineHeight: 18,
  },
  compileHint: {
    fontSize: 13,
    color: Colors.mutedText,
    marginBottom: 12,
    lineHeight: 18,
  },
  compileOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(248,247,244,0.92)',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 16,
    zIndex: 999,
    elevation: 999,
  },
  compileOverlayText: {
    fontSize: 15,
    fontWeight: '600',
    color: Colors.shadowGrey,
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
  photoThumb: {
    width: 80,
    height: 80,
    borderRadius: Radius.md,
    backgroundColor: Colors.soft,
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
    overflow: 'hidden',
  },
  modalPhotoPreview: {
    width: 120,
    height: 120,
    borderRadius: Radius.lg,
  },
  modalPhotoIcon: { fontSize: 32 },
  modalPhotoLabel: { fontSize: 12, color: Colors.mutedText, fontWeight: '500', textAlign: 'center', paddingHorizontal: 8 },
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
