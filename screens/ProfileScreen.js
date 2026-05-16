import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Modal,
  Switch,
  TouchableOpacity,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { LinearGradient } from 'expo-linear-gradient';
import { BlurView } from 'expo-blur';

import { useTheme } from '../src/AppTheme';
import Blobs from '../src/components/Blobs';
import PressScale from '../src/components/PressScale';
import VouchScoreRing from '../src/components/VouchScoreRing';
import { Colors, Shadow, Radius } from '../src/theme';

// ---------------------------------------------------------------------------
// Availability states
// ---------------------------------------------------------------------------
const AV_STATES = [
  { label: 'Available', color: '#22C55E' },
  { label: 'Busy',      color: '#F59E0B' },
  { label: 'Away',      color: Colors.dimText },
];

// ---------------------------------------------------------------------------
// Inline placeholder modal factory
// ---------------------------------------------------------------------------
function PlaceholderModal({ visible, title, onClose, accent }) {
  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}
    >
      <SafeAreaView style={[plStyles.root, { backgroundColor: Colors.canvas }]} edges={['top', 'bottom']}>
        <Blobs accent={accent} opacity={0.5} />
        <View style={plStyles.inner}>
          <Text style={plStyles.title}>{title}</Text>
          <Text style={plStyles.sub}>This screen will be wired in App.js</Text>
          <PressScale
            onPress={onClose}
            style={[plStyles.closeBtn, { backgroundColor: accent }]}
          >
            <Text style={plStyles.closeBtnText}>Close</Text>
          </PressScale>
        </View>
      </SafeAreaView>
    </Modal>
  );
}

const plStyles = StyleSheet.create({
  root:     { flex: 1 },
  inner:    { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 32 },
  title:    { fontSize: 22, fontWeight: '800', color: Colors.shadowGrey, letterSpacing: -0.5, marginBottom: 8 },
  sub:      { fontSize: 14, color: Colors.mutedText, marginBottom: 32, textAlign: 'center' },
  closeBtn: { borderRadius: 14, paddingHorizontal: 36, paddingVertical: 14 },
  closeBtnText: { color: '#fff', fontSize: 15, fontWeight: '700' },
});

// ---------------------------------------------------------------------------
// Skill chip
// ---------------------------------------------------------------------------
function SkillChip({ label, verified, accent }) {
  return (
    <View style={[
      chipStyles.chip,
      verified
        ? { borderColor: Colors.verifiedBlue, borderWidth: 1.5, backgroundColor: 'rgba(59,130,246,0.06)' }
        : { borderColor: 'rgba(39,41,50,0.12)', borderWidth: 1, backgroundColor: Colors.soft },
    ]}>
      <Text style={[
        chipStyles.label,
        { color: verified ? Colors.verifiedBlue : Colors.mutedText },
      ]}>
        {label}
      </Text>
      {verified && (
        <Text style={chipStyles.checkmark}> ✓</Text>
      )}
    </View>
  );
}

const chipStyles = StyleSheet.create({
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 20,
    paddingHorizontal: 12,
    paddingVertical: 6,
    marginRight: 8,
    marginBottom: 8,
  },
  label:     { fontSize: 13, fontWeight: '600' },
  checkmark: { fontSize: 11, fontWeight: '800', color: Colors.verifiedBlue },
});

// ---------------------------------------------------------------------------
// Stat column (used inside profile card)
// ---------------------------------------------------------------------------
function StatCol({ value, label, borderRight }) {
  return (
    <View style={[statColStyles.col, borderRight && statColStyles.borderRight]}>
      <Text style={statColStyles.value}>{value}</Text>
      <Text style={statColStyles.label}>{label}</Text>
    </View>
  );
}

const statColStyles = StyleSheet.create({
  col:         { flex: 1, alignItems: 'center', paddingVertical: 2 },
  borderRight: { borderRightWidth: 1, borderRightColor: 'rgba(39,41,50,0.10)' },
  value:       { fontSize: 17, fontWeight: '800', color: Colors.shadowGrey, letterSpacing: -0.3 },
  label:       { fontSize: 11, color: Colors.dimText, marginTop: 2, fontWeight: '500' },
});

// ---------------------------------------------------------------------------
// Work stat card (2×2 grid, isSelf only)
// ---------------------------------------------------------------------------
function WorkStatCard({ value, label }) {
  return (
    <View style={[wsStyles.card, Shadow.card]}>
      <Text style={wsStyles.value}>{value}</Text>
      <Text style={wsStyles.label}>{label}</Text>
    </View>
  );
}

const wsStyles = StyleSheet.create({
  card:  {
    width: '47%',
    backgroundColor: Colors.white,
    borderRadius: 16,
    padding: 16,
    marginBottom: 12,
  },
  value: { fontSize: 24, fontWeight: '800', color: Colors.shadowGrey, letterSpacing: -0.6, marginBottom: 4 },
  label: { fontSize: 12, color: Colors.dimText },
});

// ---------------------------------------------------------------------------
// Tab bar item
// ---------------------------------------------------------------------------
function TabItem({ emoji, label, active, accent, onPress }) {
  return (
    <TouchableOpacity style={tabStyles.item} onPress={onPress} activeOpacity={0.75}>
      <Text style={[tabStyles.emoji, { color: active ? accent : 'rgba(39,41,50,0.28)' }]}>{emoji}</Text>
      <Text style={[tabStyles.label, { color: active ? accent : Colors.dimText }]}>{label}</Text>
      {active && <View style={[tabStyles.dot, { backgroundColor: accent }]} />}
    </TouchableOpacity>
  );
}

const tabStyles = StyleSheet.create({
  item:  { flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: 8, gap: 2 },
  emoji: { fontSize: 20 },
  label: { fontSize: 10, fontWeight: '700' },
  dot:   { width: 4, height: 4, borderRadius: 2, marginTop: 2 },
});

// ---------------------------------------------------------------------------
// Main ProfileScreen
// ---------------------------------------------------------------------------
export default function ProfileScreen({
  userName = 'Ramesh Kumar',
  worker = null,
  voiceInterviewService,   // ignored — stubbed on RN
  onBack = null,
  onExplore = null,
}) {
  const { accent, t } = useTheme();
  const insets = useSafeAreaInsets();

  // ---- Derived display values --------------------------------------------
  const isSelf         = worker == null;
  const displayName    = worker?.name    ?? userName;
  const displayTrade   = worker?.trade   ?? t('Electrician · 8 yrs exp', 'इलेक्ट्रीशियन · 8 वर्ष अनुभव');
  const displayLocation = (worker?.location?.split('·')[0]?.trim()) ?? 'Mumbai';
  const displayJobs    = worker ? String(worker.jobs) : '48';
  const displayRating  = worker?.rating  ?? '4.9';
  const displayVouchScore = worker?.vouchScore ?? 73;
  const skills         = worker?.tags    ?? ['Wiring', 'Installation', 'Repair', 'Maintenance', 'Circuit', 'Equipment'];
  const verifiedIndices = worker?.verifiedTagIndices ?? new Set([0, 1]);
  const avatarGradientEnd = worker ? worker.gradientEndHex : accent;
  const initials       = worker
    ? worker.initials
    : displayName.split(' ').map(p => p[0]).join('').slice(0, 2).toUpperCase();

  // ---- State --------------------------------------------------------------
  const [activeTab,          setActiveTab]          = useState(isSelf ? 2 : 0);
  const [showVoiceInterview, setShowVoiceInterview] = useState(false);
  const [showProofOfWork,    setShowProofOfWork]    = useState(false);
  const [showGiveVouch,      setShowGiveVouch]      = useState(false);
  const [showSettings,       setShowSettings]       = useState(false);
  const [showAddSheet,       setShowAddSheet]       = useState(false);
  const [isSaved,            setIsSaved]            = useState(false);
  const [availability,       setAvailability]       = useState(0);  // 0=Available 1=Busy 2=Away

  // -------------------------------------------------------------------------
  return (
    <SafeAreaView style={styles.root} edges={['top']}>
      <StatusBar style="dark" />

      {/* Background blobs */}
      <Blobs accent={accent} opacity={0.55} />

      {/* ── Header ─────────────────────────────────────────────────────────── */}
      <View style={[styles.header, { paddingTop: 8 }]}>
        {isSelf ? (
          <>
            <Text style={styles.headerLogo}>GrayMan</Text>
            <View style={styles.liveRow}>
              <View style={[styles.liveDot, { backgroundColor: accent }]} />
              <Text style={[styles.liveText, { color: accent }]}>
                {t('Live', 'लाइव')}
              </Text>
            </View>
          </>
        ) : (
          <PressScale onPress={onBack} style={styles.backBtn}>
            <Text style={styles.backArrow}>←</Text>
          </PressScale>
        )}
      </View>

      {/* ── Scrollable body ─────────────────────────────────────────────────── */}
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={[styles.scroll, { paddingBottom: 120 }]}
      >

        {/* ── Profile card ─────────────────────────────────────────────────── */}
        <View style={[styles.profileCard, Shadow.card]}>
          {/* Top row: avatar + info + vouch ring */}
          <View style={styles.cardTop}>
            {/* Avatar */}
            <LinearGradient
              colors={[Colors.shadowGrey, avatarGradientEnd]}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.avatar}
            >
              <Text style={styles.avatarText}>{initials}</Text>
            </LinearGradient>

            {/* Name / trade / location */}
            <View style={styles.cardInfo}>
              <View style={styles.nameRow}>
                <Text style={styles.nameText} numberOfLines={1}>{displayName}</Text>
                <View style={[styles.verifiedBadge, { backgroundColor: Colors.verifiedBlue }]}>
                  <Text style={styles.verifiedCheck}>✓</Text>
                </View>
              </View>
              <Text style={styles.tradeText}>{displayTrade}</Text>
              <Text style={styles.locationText}>📍 {displayLocation}</Text>
              <View style={styles.availRow}>
                <Text style={[styles.availDot, { color: AV_STATES[isSelf ? availability : 0].color }]}>● </Text>
                <Text style={[styles.availLabel, { color: AV_STATES[isSelf ? availability : 0].color }]}>
                  {t(AV_STATES[isSelf ? availability : 0].label, AV_STATES[isSelf ? availability : 0].label)}
                </Text>
              </View>
            </View>

            {/* Vouch ring */}
            <VouchScoreRing score={displayVouchScore} size={64} accent={accent} />
          </View>

          {/* Stat row */}
          <View style={styles.statDivider} />
          <View style={styles.statRow}>
            <StatCol value={displayJobs}    label={t('Jobs', 'काम')}       borderRight />
            <StatCol value="₹500"           label={t('Per Day', 'प्रति दिन')} borderRight />
            <StatCol value={`${displayRating}★`} label={t('Rating', 'रेटिंग')}  borderRight />
            <StatCol value="8yr"            label={t('Exp', 'अनुभव')} />
          </View>
        </View>

        {/* ── Skills ──────────────────────────────────────────────────────── */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>{t('SKILLS', 'कौशल')}</Text>
          <View style={styles.skillsWrap}>
            {skills.map((skill, idx) => (
              <SkillChip
                key={`${skill}-${idx}`}
                label={skill}
                verified={verifiedIndices.has(idx)}
                accent={accent}
              />
            ))}
          </View>
        </View>

        {/* ── Work stats (isSelf only) ─────────────────────────────────────── */}
        {isSelf && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>{t('WORK STATS', 'काम के आँकड़े')}</Text>
            <View style={styles.workStatsGrid}>
              <WorkStatCard value="48"   label={t('Jobs Done', 'काम पूरे')} />
              <WorkStatCard value="₹42K" label={t('Monthly', 'मासिक')} />
              <WorkStatCard value="4.9"  label={t('Rating', 'रेटिंग')} />
              <WorkStatCard value="38"   label={t('Repeat Clients', 'नियमित ग्राहक')} />
            </View>
          </View>
        )}

        {/* ── Availability toggle (isSelf only) ───────────────────────────── */}
        {isSelf && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>{t('AVAILABILITY', 'उपलब्धता')}</Text>
            <View style={styles.avContainer}>
              {AV_STATES.map((av, idx) => {
                const active = availability === idx;
                return (
                  <PressScale
                    key={av.label}
                    onPress={() => setAvailability(idx)}
                    style={[
                      styles.avBtn,
                      active && { backgroundColor: av.color, ...Shadow.card },
                    ]}
                  >
                    <Text style={[styles.avBtnText, { color: active ? '#fff' : Colors.dimText }]}>
                      {t(av.label, av.label)}
                    </Text>
                  </PressScale>
                );
              })}
            </View>
          </View>
        )}

        {/* ── Actions ─────────────────────────────────────────────────────── */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>{t('ACTIONS', 'क्रियाएँ')}</Text>

          {isSelf ? (
            /* Self mode: 4 stacked buttons */
            <View style={styles.selfActions}>
              <PressScale style={styles.selfActionBtn}>
                <Text style={[styles.selfActionText, { color: Colors.shadowGrey }]}>
                  {t('Edit Profile', 'प्रोफाइल संपादित करें')}
                </Text>
              </PressScale>

              <PressScale style={styles.selfActionBtn}>
                <Text style={[styles.selfActionText, { color: Colors.shadowGrey }]}>
                  {t('Share', 'शेयर करें')}
                </Text>
              </PressScale>

              <PressScale
                onPress={() => setShowVoiceInterview(true)}
                style={[styles.selfActionBtnOutline, { borderColor: accent }]}
              >
                <Text style={[styles.selfActionText, { color: accent }]}>
                  {t('Practice AI Interview', 'AI इंटरव्यू अभ्यास')}
                </Text>
              </PressScale>

              <PressScale
                onPress={() => setShowProofOfWork(true)}
                style={[styles.selfActionBtnOutline, { borderColor: accent }]}
              >
                <Text style={[styles.selfActionText, { color: accent }]}>
                  {t('Add Proof of Work', 'काम का प्रमाण जोड़ें')}
                </Text>
              </PressScale>
            </View>
          ) : (
            /* Worker mode: Hire Now + 4-column row */
            <View style={styles.workerActions}>
              <PressScale
                style={[
                  styles.hireBtn,
                  { backgroundColor: accent, shadowColor: accent },
                ]}
              >
                <Text style={styles.hireBtnText}>⚡ {t('Hire Now', 'अभी काम दें')}</Text>
              </PressScale>

              <View style={styles.workerActionsRow}>
                {/* Call */}
                <PressScale style={styles.workerActionBtn}>
                  <Text style={styles.workerActionEmoji}>📞</Text>
                  <Text style={[styles.workerActionLabel, { color: Colors.shadowGrey }]}>
                    {t('Call', 'कॉल')}
                  </Text>
                </PressScale>

                {/* WhatsApp */}
                <PressScale style={styles.workerActionBtn}>
                  <Text style={styles.workerActionEmoji}>💬</Text>
                  <Text style={[styles.workerActionLabel, { color: '#25D366' }]}>
                    {t('WhatsApp', 'WhatsApp')}
                  </Text>
                </PressScale>

                {/* Vouch */}
                <PressScale
                  onPress={() => setShowGiveVouch(true)}
                  style={styles.workerActionBtn}
                >
                  <Text style={styles.workerActionEmoji}>🤝</Text>
                  <Text style={[styles.workerActionLabel, { color: Colors.verifiedBlue }]}>
                    {t('Vouch', 'वाउच')}
                  </Text>
                </PressScale>

                {/* Save */}
                <PressScale
                  onPress={() => setIsSaved(s => !s)}
                  style={styles.workerActionBtn}
                >
                  <Text style={styles.workerActionEmoji}>{isSaved ? '🔖' : '🔖'}</Text>
                  <Text style={[
                    styles.workerActionLabel,
                    { color: isSaved ? accent : Colors.mutedText },
                  ]}>
                    {isSaved ? t('Saved', 'सेव किया') : t('Save', 'सेव करें')}
                  </Text>
                </PressScale>
              </View>
            </View>
          )}
        </View>
      </ScrollView>

      {/* ── Glass tab bar ───────────────────────────────────────────────────── */}
      <BlurView
        intensity={90}
        tint="light"
        style={[styles.tabBar, { bottom: Math.max(insets.bottom, 16) }]}
      >
        <TabItem
          emoji="🏠"
          label={t('Home', 'होम')}
          active={activeTab === 0}
          accent={accent}
          onPress={() => setActiveTab(0)}
        />
        <TabItem
          emoji="🔍"
          label={t('Explore', 'खोजें')}
          active={activeTab === 1}
          accent={accent}
          onPress={() => { setActiveTab(1); onExplore?.(); }}
        />
        <TabItem
          emoji="⚙️"
          label={t('Settings', 'सेटिंग्स')}
          active={activeTab === 2}
          accent={accent}
          onPress={() => { setActiveTab(2); setShowSettings(true); }}
        />
      </BlurView>

      {/* ── Modals ──────────────────────────────────────────────────────────── */}

      {/* 1. AI Voice Interview */}
      <PlaceholderModal
        visible={showVoiceInterview}
        title={t('AI Interview', 'AI इंटरव्यू')}
        onClose={() => setShowVoiceInterview(false)}
        accent={accent}
      />

      {/* 2. Proof of Work */}
      <PlaceholderModal
        visible={showProofOfWork}
        title={t('Proof of Work', 'काम का प्रमाण')}
        onClose={() => setShowProofOfWork(false)}
        accent={accent}
      />

      {/* 3. Give Vouch */}
      <PlaceholderModal
        visible={showGiveVouch}
        title={t('Give a Vouch', 'वाउच दें')}
        onClose={() => setShowGiveVouch(false)}
        accent={accent}
      />

      {/* 4. Settings */}
      <PlaceholderModal
        visible={showSettings}
        title={t('Settings', 'सेटिंग्स')}
        onClose={() => setShowSettings(false)}
        accent={accent}
      />
    </SafeAreaView>
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

  // Header
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 24,
    paddingBottom: 8,
    height: 52,
  },
  headerLogo: {
    fontSize: 17,
    fontWeight: '800',
    letterSpacing: -0.34,
    color: Colors.shadowGrey,
  },
  liveRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
  },
  liveDot: {
    width: 7,
    height: 7,
    borderRadius: 3.5,
  },
  liveText: {
    fontSize: 14,
    fontWeight: '600',
    letterSpacing: -0.14,
  },
  backBtn: {
    width: 36,
    height: 36,
    borderRadius: Radius.md,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  backArrow: {
    fontSize: 18,
    color: Colors.shadowGrey,
    lineHeight: 22,
  },

  // Scroll
  scroll: {
    paddingHorizontal: 20,
    paddingTop: 6,
  },

  // Profile card
  profileCard: {
    backgroundColor: Colors.white,
    borderRadius: 24,
    padding: 20,
    marginBottom: 28,
  },
  cardTop: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 14,
    marginBottom: 16,
  },
  avatar: {
    width: 72,
    height: 72,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.22,
    shadowRadius: 16,
    elevation: 6,
  },
  avatarText: {
    fontSize: 24,
    fontWeight: '800',
    color: '#fff',
    letterSpacing: -0.5,
  },
  cardInfo: {
    flex: 1,
    paddingTop: 2,
    gap: 3,
  },
  nameRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: 2,
  },
  nameText: {
    fontSize: 18,
    fontWeight: '800',
    color: Colors.shadowGrey,
    letterSpacing: -0.36,
    flexShrink: 1,
  },
  verifiedBadge: {
    width: 18,
    height: 18,
    borderRadius: 9,
    alignItems: 'center',
    justifyContent: 'center',
  },
  verifiedCheck: {
    fontSize: 10,
    fontWeight: '800',
    color: '#fff',
    lineHeight: 13,
  },
  tradeText: {
    fontSize: 14,
    color: Colors.mutedText,
  },
  locationText: {
    fontSize: 13,
    color: Colors.dimText,
  },
  availRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 2,
  },
  availDot: {
    fontSize: 10,
    fontWeight: '800',
  },
  availLabel: {
    fontSize: 12,
    fontWeight: '600',
  },
  statDivider: {
    height: 1,
    backgroundColor: 'rgba(39,41,50,0.08)',
    marginBottom: 14,
  },
  statRow: {
    flexDirection: 'row',
  },

  // Section
  section: {
    marginBottom: 28,
  },
  sectionTitle: {
    fontSize: 11,
    fontWeight: '800',
    color: Colors.dimText,
    letterSpacing: 1,
    marginBottom: 12,
    textTransform: 'uppercase',
  },

  // Skills
  skillsWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },

  // Work stats grid
  workStatsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },

  // Availability toggle
  avContainer: {
    flexDirection: 'row',
    backgroundColor: Colors.soft,
    borderRadius: 14,
    padding: 4,
    gap: 4,
  },
  avBtn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 10,
    alignItems: 'center',
  },
  avBtnText: {
    fontSize: 13,
    fontWeight: '700',
  },

  // Self actions
  selfActions: {
    gap: 10,
  },
  selfActionBtn: {
    backgroundColor: Colors.soft,
    borderRadius: 14,
    paddingVertical: 16,
    alignItems: 'center',
  },
  selfActionBtnOutline: {
    borderRadius: 14,
    paddingVertical: 16,
    alignItems: 'center',
    borderWidth: 1.5,
    backgroundColor: 'transparent',
  },
  selfActionText: {
    fontSize: 15,
    fontWeight: '700',
  },

  // Worker mode actions
  workerActions: {
    gap: 10,
  },
  hireBtn: {
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.30,
    shadowRadius: 18,
    elevation: 8,
  },
  hireBtnText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
    letterSpacing: -0.16,
  },
  workerActionsRow: {
    flexDirection: 'row',
    gap: 8,
  },
  workerActionBtn: {
    flex: 1,
    backgroundColor: Colors.soft,
    borderRadius: 14,
    paddingVertical: 12,
    alignItems: 'center',
    gap: 4,
  },
  workerActionEmoji: {
    fontSize: 20,
  },
  workerActionLabel: {
    fontSize: 12,
    fontWeight: '700',
  },

  // Tab bar
  tabBar: {
    position: 'absolute',
    left: 12,
    right: 12,
    height: 68,
    borderRadius: 24,
    flexDirection: 'row',
    alignItems: 'center',
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.90)',
  },
});
