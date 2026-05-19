import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Modal,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  Linking,
  TextInput,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { LinearGradient } from 'expo-linear-gradient';
import { BlurView } from 'expo-blur';
import { Platform } from 'react-native';

import { useTheme } from '../src/AppTheme';
import Blobs from '../src/components/Blobs';
import PressScale from '../src/components/PressScale';
import VouchScoreRing from '../src/components/VouchScoreRing';
import { workerService } from '../src/api/workerService';
import { Colors, Glass } from '../src/theme';
import AppIcon, { Icons, IconLabel } from '../src/components/AppIcon';

import NotificationsScreen from './NotificationsScreen';
import VoiceInterviewScreen from './VoiceInterviewScreen';
import ProofOfWorkScreen from './ProofOfWorkScreen';
import GiveVouchSheet from './GiveVouchSheet';
import SettingsScreen from './SettingsScreen';

// ---------------------------------------------------------------------------
// Platform-aware glass surface (BlurView on iOS, styled View on Android)
// ---------------------------------------------------------------------------
function GlassCard({ style, children }) {
  if (Platform.OS === 'ios') {
    return (
      <BlurView intensity={Glass.regular.intensity} tint={Glass.regular.tint} style={style}>
        {children}
      </BlurView>
    );
  }
  return (
    <View style={[{
      backgroundColor: Glass.regular.backgroundColor,
      borderColor: Glass.regular.borderColor,
      borderWidth: Glass.regular.borderWidth,
    }, style]}>
      {children}
    </View>
  );
}

// ---------------------------------------------------------------------------
// Skill chip
// ---------------------------------------------------------------------------
function SkillChip({ label, verified, active, onPress, accent }) {
  return (
    <PressScale onPress={onPress}>
      <View style={[
        styles.chip,
        active ? { backgroundColor: 'rgba(39,41,50,0.06)', borderColor: 'rgba(39,41,50,0.38)' } : { backgroundColor: 'transparent', borderColor: 'rgba(39,41,50,0.13)' }
      ]}>
        <Text style={[
          styles.chipLabel,
          { color: active ? accent : Colors.mutedText },
        ]}>
          {label}
        </Text>
        {verified && (
          <AppIcon name={Icons.checkmarkSeal} size={14} color={Colors.verifiedBlue} style={{ marginLeft: 4 }} />
        )}
      </View>
    </PressScale>
  );
}

// ---------------------------------------------------------------------------
// Stat column
// ---------------------------------------------------------------------------
function StatCol({ value, label, borderRight }) {
  return (
    <View style={[styles.statCol, borderRight && styles.statBorderRight]}>
      {typeof value === 'string' ? (
        <Text style={styles.statValue}>{value}</Text>
      ) : (
        value
      )}
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Tab bar item
// ---------------------------------------------------------------------------
function TabItem({ icon, label, active, accent, onPress }) {
  return (
    <TouchableOpacity style={styles.tabItem} onPress={onPress} activeOpacity={0.75}>
      <AppIcon
        name={icon}
        size={22}
        color={active ? accent : 'rgba(39,41,50,0.35)'}
      />
      <Text style={[styles.tabLabel, { color: active ? accent : Colors.dimText }]}>{label}</Text>
    </TouchableOpacity>
  );
}

export default function ProfileScreen({
  userName = 'Ramesh Kumar',
  worker: workerProp = null,
  onBack = null,
  onExplore = null,
  onSignOut = null,
  onRecordReel = null,
}) {
  const { accent, t } = useTheme();
  const insets = useSafeAreaInsets();

  const isSelf = workerProp == null;
  const [profile, setProfile] = useState(workerProp);
  const [loading, setLoading] = useState(isSelf && !workerProp);
  const [canVouch, setCanVouch] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const [workHistory, setWorkHistory] = useState([]);
  const [selectedSkills, setSelectedSkills] = useState(new Set([0, 1]));

  const loadProfile = useCallback(async () => {
    if (workerProp) {
      setProfile(workerProp);
      try {
        const can = await workerService.hasCompletedHire(workerProp.id);
        setCanVouch(can);
        const history = await workerService.fetchWorkHistory(workerProp.id);
        setWorkHistory(history || []);
      } catch { /* ignore */ }
      return;
    }
    setLoading(true);
    try {
      const w = await workerService.fetchSelf();
      setProfile(w);
      workerService.syncSelfLocationIfNeeded();
      const notifs = await workerService.fetchNotifications(true, 20);
      setUnreadCount((notifs?.notifications || notifs || []).length);
      const history = await workerService.fetchWorkHistory(w.id);
      setWorkHistory(history || []);
    } catch (e) {
      // Alert.alert('Error', e.message || 'Could not load profile');
    } finally {
      setLoading(false);
    }
  }, [workerProp]);

  useEffect(() => {
    loadProfile();
  }, [loadProfile]);

  const worker = profile;

  // Derived
  const displayName = worker?.name ?? (userName || 'Your name');
  const displayTrade = worker?.trade ?? 'Your trade';
  const displayLocation = worker?.location?.split('·')[0]?.trim() ?? 'Locating…';
  const displayJobs = worker ? String(worker.jobs) : '00';
  const displayRating = worker?.rating ?? '0.0';
  const displayVouchScore = worker?.vouchScore ?? 0;
  const skills = worker?.tags?.length ? worker.tags : (loading ? ['Skill one', 'Skill two'] : []);
  const verifiedIndices = worker?.verifiedTagIndices ?? new Set();
  const avatarGradientEnd = worker ? worker.gradientEndHex : accent;
  const initials = worker
    ? worker.initials
    : displayName.split(' ').map(p => p[0]).join('').slice(0, 2).toUpperCase();

  // States
  const [activeTab, setActiveTab] = useState(isSelf ? 0 : 0);
  const [showVoiceInterview, setShowVoiceInterview] = useState(false);
  const [showProofOfWork, setShowProofOfWork] = useState(false);
  const [showGiveVouch, setShowGiveVouch] = useState(false);
  const [showSettings, setShowSettings] = useState(false);
  const [showAddSheet, setShowAddSheet] = useState(false);
  const [showWorkHistoryEditor, setShowWorkHistoryEditor] = useState(false);
  const [isSaved, setIsSaved] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);

  useEffect(() => {
    if (!worker?.id || isSelf) return;
    workerService.fetchMyActionState(worker.id).then(s => {
      setIsSaved(s?.has_saved ?? false);
    }).catch(() => {});
  }, [worker?.id, isSelf]);

  const toggleSave = async () => {
    if (!worker?.id) return;
    try {
      if (isSaved) {
        await workerService.unsave(worker.id);
        setIsSaved(false);
      } else {
        await workerService.save(worker.id);
        setIsSaved(true);
      }
    } catch (e) {
      Alert.alert('Error', e.message);
    }
  };

  const requestHire = async () => {
    if (!worker?.id) return;
    try {
      await workerService.createHire(worker.id);
      Alert.alert(t('Result', 'स्थिति'), t('Hire request sent. They\'ll be notified.', 'अनुरोध भेज दिया गया। उन्हें सूचना मिलेगी।'));
    } catch (e) {
      Alert.alert('Error', e.message);
    }
  };

  const toggleSkill = (idx) => {
    const next = new Set(selectedSkills);
    if (next.has(idx)) next.delete(idx);
    else next.add(idx);
    setSelectedSkills(next);
  };

  return (
    <View style={styles.root}>
      <StatusBar style="dark" />
      <Blobs accent={accent} opacity={0.55} />

      <SafeAreaView edges={['top']} style={{ flex: 1 }}>
        <View style={[styles.header, { paddingHorizontal: isSelf ? 28 : 20 }]}>
          {onBack ? (
            <PressScale onPress={onBack} style={styles.backBtn}>
              <Text style={styles.backArrow}>←</Text>
            </PressScale>
          ) : (
            <>
              <Text style={styles.headerLogo}>sthapna.ai</Text>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14 }}>
                <PressScale onPress={() => setShowNotifications(true)} style={styles.notifBtn}>
                  <AppIcon name={Icons.bell} size={22} color={Colors.shadowGrey} />
                  {unreadCount > 0 && (
                    <View style={[styles.notifBadge, { backgroundColor: accent }]}>
                      <Text style={styles.notifBadgeText}>{unreadCount}</Text>
                    </View>
                  )}
                </PressScale>
                <View style={styles.liveRow}>
                  <View style={[styles.liveDot, { backgroundColor: accent }]} />
                  <Text style={[styles.liveText, { color: Colors.shadowGrey }]}>
                    {t('Live', 'लाइव')}
                  </Text>
                </View>
              </View>
            </>
          )}
        </View>

        <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={[styles.scroll, { paddingBottom: 120 }]}>
          {/* Profile Card (Glass #1) */}
          <GlassCard style={styles.profileCard}>
            <View style={styles.cardTop}>
              <LinearGradient
                colors={[Colors.shadowGrey, avatarGradientEnd]}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.avatar}
              >
                <Text style={styles.avatarText}>{initials}</Text>
              </LinearGradient>

              <View style={styles.cardInfo}>
                <View style={styles.nameRow}>
                  <Text style={styles.nameText} numberOfLines={1}>{displayName}</Text>
                  {worker?.isVerified && (
                    <View style={[styles.verifiedBadge, { backgroundColor: Colors.verifiedBlue }]}>
                      <AppIcon name={Icons.checkmark} size={12} color="#fff" />
                    </View>
                  )}
                </View>
                <Text style={styles.tradeText}>{displayTrade}</Text>
                <View style={styles.availRow}>
                  <View style={styles.locationRow}>
                    <AppIcon name={Icons.location} size={13} color={Colors.mutedText} />
                    <Text style={styles.locationText}>{displayLocation}</Text>
                  </View>
                  <Text style={[styles.availLabel, { color: accent }]}>● {t('Available', 'उपलब्ध')}</Text>
                </View>
              </View>

              <PressScale onPress={() => {
                if (!isSelf) {
                  if (canVouch) setShowGiveVouch(true);
                  else Alert.alert(t('Vouch not yet available', 'वाउच अभी उपलब्ध नहीं'), t("You can vouch for this worker only after you've hired them and marked the job complete. Trust the platform — trust the vouch.", "आप इस कारीगर के लिए वाउच केवल तब कर सकते हैं जब आपने उन्हें काम दिया हो और काम पूरा होने की पुष्टि की हो। भरोसा प्लेटफ़ॉर्म पर — भरोसा वाउच पर।"));
                }
              }}>
                <VouchScoreRing score={displayVouchScore} size={62} accent={accent} />
              </PressScale>
            </View>

            <View style={styles.statDivider} />
            <View style={styles.statRow}>
              <StatCol value={displayJobs} label={t('Jobs', 'काम')} borderRight />
              <StatCol
                value={(
                  <View style={styles.statRatingRow}>
                    <Text style={styles.statValue}>{displayRating}</Text>
                    <AppIcon name={Icons.starFill} size={16} color="#F4A261" />
                  </View>
                )}
                label={t('Rating', 'रेटिंग')}
              />
            </View>
          </GlassCard>

          {/* Skills */}
          {skills.length > 0 && (
            <View style={styles.section}>
              <Text style={styles.sectionLabel}>{t('Skills', 'कौशल').toUpperCase()}</Text>
              <View style={styles.skillsWrap}>
                {skills.map((skill, idx) => (
                  <SkillChip
                    key={`${skill}-${idx}`}
                    label={skill}
                    verified={verifiedIndices.has(idx)}
                    active={selectedSkills.has(idx)}
                    accent={accent}
                    onPress={() => toggleSkill(idx)}
                  />
                ))}
              </View>
            </View>
          )}

          {/* Work History */}
          {(isSelf || workHistory.length > 0) && (
            <View style={styles.section}>
              <Text style={styles.sectionLabel}>{t('Work History', 'कार्य इतिहास').toUpperCase()}</Text>
              <View style={styles.workHistoryList}>
                {workHistory.length === 0 ? (
                  <Text style={styles.emptyHistoryText}>
                    {t(
                      "No work history yet. Add roles you've worked to build trust.",
                      'अभी कोई कार्य इतिहास नहीं। भरोसा बनाने के लिए अपनी भूमिकाएँ जोड़ें।',
                    )}
                  </Text>
                ) : (
                  workHistory.map((dto, idx) => (
                    <View key={dto.id || idx} style={styles.historyRow}>
                      <View style={styles.historyTimeline}>
                        <View style={[styles.historyDot, { backgroundColor: idx === 0 ? accent : 'rgba(39,41,50,0.18)' }]} />
                        {idx < workHistory.length - 1 && <View style={styles.historyLine} />}
                      </View>
                      <View style={styles.historyContent}>
                        <View style={styles.historyTitleRow}>
                          <Text style={styles.historyRole}>{dto.role}</Text>
                          <Text style={styles.historyPeriod}>{dto.periodLabel || dto.period}</Text>
                        </View>
                        {!!dto.client && <Text style={[styles.historyClient, { color: accent }]}>{dto.client}</Text>}
                        {!!dto.description && <Text style={styles.historyDesc} numberOfLines={3}>{dto.description}</Text>}
                      </View>
                    </View>
                  ))
                )}
                {isSelf && (
                  <PressScale onPress={() => setShowWorkHistoryEditor(true)} style={styles.addWorkHistoryBtn}>
                    <Text style={styles.addWorkHistoryText}>+ {t('Add Work History', 'कार्य इतिहास जोड़ें')}</Text>
                  </PressScale>
                )}
              </View>
            </View>
          )}

          {/* Showcase Work Button */}
          <PressScale onPress={() => setShowProofOfWork(true)} style={styles.showcaseBtn}>
            <IconLabel icon="play" size={18} color="#fff" textStyle={styles.showcaseBtnText}>
              {t('Showcase Work', 'अपना काम दिखाएँ')}
            </IconLabel>
          </PressScale>

          {/* Actions */}
          <View style={styles.section}>
            <Text style={styles.sectionLabel}>
              {isSelf ? t('Profile', 'प्रोफ़ाइल').toUpperCase() : t('Actions', 'कार्रवाई').toUpperCase()}
            </Text>
            
            {isSelf ? (
              <View style={styles.actionsGrid}>
                <View style={{ flexDirection: 'row', gap: 10 }}>
                  <PressScale style={styles.actionBtnOutline}>
                    <IconLabel icon="create-outline" size={18} color={Colors.shadowGrey} textStyle={[styles.actionBtnText, { color: Colors.shadowGrey }]}>
                      {t('Edit Profile', 'प्रोफ़ाइल संपादित करें')}
                    </IconLabel>
                  </PressScale>
                  <PressScale style={[styles.actionBtnFilled, { backgroundColor: accent }]}>
                    <IconLabel icon={Icons.share} size={18} color="#fff" textStyle={[styles.actionBtnText, { color: '#fff' }]}>
                      {t('Share', 'शेयर करें')}
                    </IconLabel>
                  </PressScale>
                </View>
                <PressScale onPress={() => setShowVoiceInterview(true)} style={[styles.actionBtnOutline, { borderColor: 'rgba(59,130,246,0.3)' }]}>
                  <IconLabel icon={Icons.interview} size={18} color={Colors.verifiedBlue} textStyle={[styles.actionBtnText, { color: Colors.verifiedBlue }]}>
                    {t('Practice AI Interview', 'AI इंटरव्यू अभ्यास')}
                  </IconLabel>
                </PressScale>
                <PressScale onPress={() => setShowProofOfWork(true)} style={styles.actionBtnOutline}>
                  <IconLabel icon={Icons.proof} size={18} color={Colors.shadowGrey} textStyle={[styles.actionBtnText, { color: Colors.shadowGrey }]}>
                    {t('Add Proof of Work', 'काम का सबूत जोड़ें')}
                  </IconLabel>
                </PressScale>
              </View>
            ) : (
              <View style={styles.actionsGrid}>
                <PressScale onPress={requestHire} style={[styles.actionBtnFilled, { backgroundColor: accent }]}>
                  <IconLabel icon={Icons.hire} size={18} color="#fff" textStyle={[styles.actionBtnText, { color: '#fff' }]}>
                    {t('Hire Now', 'अभी काम दें')}
                  </IconLabel>
                </PressScale>
                <View style={{ flexDirection: 'row', gap: 10 }}>
                  <PressScale onPress={() => { if (worker?.phone) Linking.openURL(`tel:${worker.phone}`) }} style={styles.actionBtnOutlineFlex}>
                    <AppIcon name="call" size={20} color={Colors.shadowGrey} />
                    <Text style={[styles.actionBtnTextSmall, { color: Colors.shadowGrey }]}>{t('Call', 'कॉल करें')}</Text>
                  </PressScale>
                  <PressScale onPress={() => { if (worker?.phone) Linking.openURL(`https://wa.me/${worker.phone.replace(/\D/g, '')}`) }} style={[styles.actionBtnOutlineFlex, { borderColor: 'rgba(37,211,102,0.25)' }]}>
                    <AppIcon name={Icons.whatsapp} size={20} color="#25D366" />
                    <Text style={[styles.actionBtnTextSmall, { color: '#25D366' }]}>{t('WhatsApp', 'WhatsApp')}</Text>
                  </PressScale>
                  <PressScale onPress={() => setShowGiveVouch(true)} style={[styles.actionBtnOutlineFlex, { borderColor: 'rgba(59,130,246,0.25)' }]}>
                    <AppIcon name={Icons.vouchFill} size={20} color={Colors.verifiedBlue} />
                    <Text style={[styles.actionBtnTextSmall, { color: Colors.verifiedBlue }]}>{t('Vouch', 'Vouch करें')}</Text>
                  </PressScale>
                  <PressScale onPress={toggleSave} style={styles.actionBtnOutlineFlex}>
                    <AppIcon name={isSaved ? Icons.bookmarkFill : Icons.bookmark} size={20} color={Colors.shadowGrey} />
                    <Text style={[styles.actionBtnTextSmall, { color: Colors.shadowGrey }]}>{isSaved ? t('Saved', 'सेव हो गया') : t('Save', 'सेव करें')}</Text>
                  </PressScale>
                </View>
              </View>
            )}
          </View>
        </ScrollView>
      </SafeAreaView>

      {/* Floating Liquid Glass Tab Bar (Glass #2) */}
      <View style={[styles.tabBarContainer, { bottom: Math.max(insets.bottom, 20) }]}>
        <GlassCard style={styles.tabBar}>
          <TabItem icon={Icons.home} label={t('Home', 'होम')} />
          <TabItem icon={Icons.explore} label={t('Explore', 'खोजें')} onPress={onExplore} />
          <PressScale onPress={() => setShowAddSheet(true)} style={[styles.addBtn, { backgroundColor: accent }]}>
            <AppIcon name={Icons.plus} size={26} color="#fff" />
          </PressScale>
          <TabItem icon={Icons.profile} label={t('Profile', 'प्रोफ़ाइल')} active={isSelf} accent={accent} />
          <TabItem icon={Icons.settings} label={t('Settings', 'सेटिंग्स')} onPress={() => setShowSettings(true)} />
        </GlassCard>
      </View>

      {/* Modals */}
      <Modal visible={showVoiceInterview} animationType="slide" presentationStyle="fullScreen">
        <VoiceInterviewScreen trade={worker?.tradeRaw || worker?.trade} onClose={() => setShowVoiceInterview(false)} />
      </Modal>

      <Modal visible={showProofOfWork} animationType="slide" presentationStyle="fullScreen">
        <ProofOfWorkScreen workerId={worker?.id} onClose={() => setShowProofOfWork(false)} />
      </Modal>

      <Modal visible={showGiveVouch} animationType="slide" presentationStyle="pageSheet">
        <GiveVouchSheet worker={worker} onClose={() => setShowGiveVouch(false)} />
      </Modal>

      <Modal visible={showSettings} animationType="slide" presentationStyle="fullScreen">
        <SettingsScreen onClose={() => setShowSettings(false)} onSignOut={onSignOut} />
      </Modal>

      <Modal visible={showNotifications} animationType="slide" presentationStyle="fullScreen">
        <NotificationsScreen onClose={() => setShowNotifications(false)} />
      </Modal>

      <Modal visible={showAddSheet} animationType="slide" presentationStyle="pageSheet">
        <View style={{flex: 1, backgroundColor: Colors.canvas, padding: 24, paddingTop: 40}}>
          <Text style={{fontSize: 22, fontWeight: '800', color: Colors.shadowGrey, marginBottom: 8}}>{t('New Job', 'नया काम')}</Text>
          <Text style={{fontSize: 14, color: Colors.mutedText, marginBottom: 20}}>
            {t('Post a job and connect with nearby skilled workers in minutes.', 'काम पोस्ट करें और मिनटों में आस-पास के कुशल कामगारों से जुड़ें।')}
          </Text>
          {['⚡ Electrical', '🔧 Plumbing', '🪚 Carpentry', '🎨 Painting'].map(item => (
            <PressScale key={item} onPress={() => setShowAddSheet(false)} style={{backgroundColor: Colors.soft, padding: 14, borderRadius: 14, marginBottom: 10}}>
              <Text style={{fontSize: 15, fontWeight: '600', color: Colors.shadowGrey}}>{item}</Text>
            </PressScale>
          ))}
          <PressScale onPress={() => setShowAddSheet(false)} style={{marginTop: 'auto', padding: 14}}>
            <Text style={{fontSize: 15, fontWeight: '600', color: Colors.mutedText, textAlign: 'center'}}>{t('Cancel', 'रद्द करें')}</Text>
          </PressScale>
        </View>
      </Modal>

      <Modal visible={showWorkHistoryEditor} animationType="slide" presentationStyle="pageSheet">
        <View style={{flex: 1, backgroundColor: Colors.canvas, padding: 24, paddingTop: 40}}>
           <Text style={{fontSize: 22, fontWeight: '800', color: Colors.shadowGrey, marginBottom: 8}}>{t('Add work history', 'कार्य इतिहास जोड़ें')}</Text>
           <Text style={{fontSize: 13, color: Colors.mutedText, marginBottom: 20}}>
             {t('Add one role at a time. You can edit or remove it later.', 'एक समय में एक भूमिका जोड़ें। आप इसे बाद में संपादित या हटा सकते हैं।')}
           </Text>
           <PressScale onPress={() => setShowWorkHistoryEditor(false)} style={[styles.actionBtnFilled, {backgroundColor: accent, marginTop: 'auto'}]}>
             <Text style={[styles.actionBtnText, {color: '#fff'}]}>{t('Cancel', 'रद्द करें')}</Text>
           </PressScale>
        </View>
      </Modal>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------
const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: Colors.canvas,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 8,
    paddingBottom: 8,
  },
  headerLogo: {
    fontSize: 17,
    fontWeight: '900',
    color: Colors.shadowGrey,
    letterSpacing: -0.3,
  },
  notifBtn: { position: 'relative' },
  notifIcon: { fontSize: 22 },
  notifBadge: {
    position: 'absolute',
    top: -4,
    right: -4,
    minWidth: 16,
    height: 16,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 4,
  },
  notifBadgeText: { color: '#fff', fontSize: 10, fontWeight: '900' },
  liveRow: { flexDirection: 'row', alignItems: 'center', gap: 5 },
  liveDot: { width: 7, height: 7, borderRadius: 3.5 },
  liveText: { fontSize: 14, fontWeight: '600' },
  backBtn: {
    width: 36,
    height: 36,
    borderRadius: 12,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  backArrow: { fontSize: 16, fontWeight: 'bold', color: Colors.shadowGrey },

  scroll: {
    paddingHorizontal: 20,
    paddingTop: 16,
  },

  // Profile Card
  profileCard: {
    borderRadius: 28,
    padding: 22,
    overflow: 'hidden',
    marginBottom: 28,
  },
  cardTop: {
    flexDirection: 'row',
    gap: 16,
    marginBottom: 18,
  },
  avatar: {
    width: 72,
    height: 72,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.2,
    shadowRadius: 12,
  },
  avatarText: { fontSize: 24, fontWeight: '900', color: '#fff' },
  cardInfo: { flex: 1, paddingTop: 2 },
  nameRow: { flexDirection: 'row', alignItems: 'center', gap: 7 },
  nameText: { fontSize: 18, fontWeight: '900', color: Colors.shadowGrey, letterSpacing: -0.4 },
  verifiedBadge: { width: 16, height: 16, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
  verifiedCheck: { fontSize: 10, fontWeight: 'bold', color: '#fff' },
  tradeText: { fontSize: 14, color: Colors.mutedText, marginBottom: 4 },
  availRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  locationRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  locationText: { fontSize: 12, color: Colors.dimText },
  statRatingRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  availLabel: { fontSize: 12, fontWeight: 'bold' },
  statDivider: { height: 1, backgroundColor: 'rgba(39,41,50,0.1)' },
  statRow: { flexDirection: 'row', paddingTop: 16 },
  statCol: { flex: 1, alignItems: 'center' },
  statBorderRight: { borderRightWidth: 1, borderRightColor: 'rgba(39,41,50,0.1)' },
  statValue: { fontSize: 18, fontWeight: '900', color: '#000', letterSpacing: -0.4 },
  statLabel: { fontSize: 11, fontWeight: '500', color: Colors.dimText, marginTop: 2 },

  // Sections
  section: { marginBottom: 28 },
  sectionLabel: { fontSize: 11, fontWeight: '900', color: Colors.dimText, letterSpacing: 1.0, marginBottom: 12 },
  
  // Skills
  skillsWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 20,
    borderWidth: 1.5,
  },
  chipLabel: { fontSize: 13, fontWeight: '600' },
  chipCheckmark: { fontSize: 11, color: Colors.verifiedBlue },

  // Work History
  workHistoryList: { gap: 18 },
  emptyHistoryText: { fontSize: 13, color: Colors.dimText },
  historyRow: { flexDirection: 'row', gap: 14 },
  historyTimeline: { width: 9, alignItems: 'center', paddingTop: 5 },
  historyDot: { width: 9, height: 9, borderRadius: 4.5 },
  historyLine: { width: 1, flex: 1, backgroundColor: 'rgba(39,41,50,0.1)', marginTop: 4, minHeight: 36 },
  historyContent: { flex: 1, gap: 3, paddingBottom: 10 },
  historyTitleRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  historyRole: { fontSize: 15, fontWeight: '900', color: Colors.shadowGrey },
  historyPeriod: { fontSize: 11, fontWeight: '600', color: Colors.dimText },
  historyClient: { fontSize: 13, fontWeight: '600', marginTop: 1 },
  historyDesc: { fontSize: 13, color: Colors.mutedText, marginTop: 2 },
  addWorkHistoryBtn: {
    paddingVertical: 13,
    borderWidth: 1.5,
    borderColor: 'rgba(39,41,50,0.16)',
    borderStyle: 'dashed',
    borderRadius: 12,
    alignItems: 'center',
    marginTop: 4,
  },
  addWorkHistoryText: { fontSize: 14, fontWeight: '600', color: Colors.dimText },

  // Showcase
  showcaseBtn: {
    backgroundColor: Colors.shadowGrey,
    paddingVertical: 17,
    borderRadius: 14,
    alignItems: 'center',
    shadowColor: Colors.shadowGrey,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.2,
    shadowRadius: 18,
    marginBottom: 28,
  },
  showcaseBtnText: { color: '#fff', fontSize: 15, fontWeight: '900' },

  // Actions
  actionsGrid: { gap: 10 },
  actionBtnOutline: {
    flex: 1,
    paddingVertical: 15,
    borderWidth: 1.5,
    borderColor: 'rgba(39,41,50,0.14)',
    borderRadius: 14,
    alignItems: 'center',
  },
  actionBtnFilled: {
    flex: 1,
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.3,
    shadowRadius: 10,
  },
  actionBtnOutlineFlex: {
    flex: 1,
    paddingVertical: 13,
    borderWidth: 1.5,
    borderColor: 'rgba(39,41,50,0.15)',
    borderRadius: 12,
    alignItems: 'center',
    gap: 4,
  },
  actionBtnText: { fontSize: 15, fontWeight: '600' },
  actionBtnTextSmall: { fontSize: 12, fontWeight: 'bold' },

  // Tab Bar
  tabBarContainer: {
    position: 'absolute',
    left: 12,
    right: 12,
    alignItems: 'center',
  },
  tabBar: {
    flexDirection: 'row',
    alignItems: 'center',
    height: 68,
    borderRadius: 34,
    paddingHorizontal: 8,
    overflow: 'hidden',
  },
  tabItem: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 3 },
  tabEmoji: { fontSize: 19 },
  tabLabel: { fontSize: 10, fontWeight: 'bold' },
  addBtn: {
    width: 46,
    height: 46,
    borderRadius: 23,
    alignItems: 'center',
    justifyContent: 'center',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.42,
    shadowRadius: 8,
  },
  addBtnText: { color: '#fff', fontSize: 22, fontWeight: 'bold' },
});
