import React, { useState, useRef, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  Dimensions,
  ActivityIndicator,
  Animated,
  PanResponder,
  Alert,
  Linking,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { LinearGradient } from 'expo-linear-gradient';
import * as Location from 'expo-location';

import { useTheme } from '../src/AppTheme';
import PressScale from '../src/components/PressScale';
import { AllCategories } from '../src/workers';
import { workerService } from '../src/api/workerService';
import { Colors } from '../src/theme';
import ExploreReelPlayer, { explorePlaybackSource } from '../src/components/ExploreReelPlayer';

const { width: SW } = Dimensions.get('window');

// ─── Helpers ──────────────────────────────────────────────────────────────────

function initials(name = '') {
  return name
    .split(' ')
    .slice(0, 2)
    .map(p => p[0] || '')
    .join('')
    .toUpperCase();
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function ActionBtn({ icon, label, tint = '#fff', onPress }) {
  return (
    <PressScale onPress={onPress} scale={0.90} style={s.actionTile}>
      <View style={s.actionCircle}>
        <Text style={[s.actionIcon, { color: tint }]}>{icon}</Text>
      </View>
      {!!label && <Text style={s.actionLabel}>{label}</Text>}
    </PressScale>
  );
}

function TabTile({ icon, label, active, accent, onPress }) {
  return (
    <Pressable onPress={onPress} style={s.tabTile}>
      <Text style={[s.tabTileIcon, active && { color: accent }]}>{icon}</Text>
      <Text style={[s.tabTileLabel, active && { color: accent }]}>{label}</Text>
    </Pressable>
  );
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

export default function ExploreScreen({ onBack, onViewProfile, onGoProfile }) {
  const { accent, t } = useTheme();
  const insets = useSafeAreaInsets();

  const [radius, setRadius] = useState(5);
  const [activeCategory, setActiveCategory] = useState('All');
  const [currentIndex, setCurrentIndex] = useState(0);
  const [workers, setWorkers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [actionStates, setActionStates] = useState({});
  const [trayOpen, setTrayOpen] = useState(false);
  const [locationGranted, setLocationGranted] = useState(null); // null = checking

  // Animated value for morphing nav width
  const trayAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.spring(trayAnim, {
      toValue: trayOpen ? 1 : 0,
      useNativeDriver: false,
      tension: 80,
      friction: 9,
    }).start();
  }, [trayOpen]);

  // ─── Location permission check ────────────────────────────────────────────
  // Android does NOT automatically re-prompt after first denial.
  // We check here and surface a clear warning so the user knows WHY
  // results may be from the wrong region.
  useEffect(() => {
    (async () => {
      const { status } = await Location.getForegroundPermissionsAsync();
      if (status === 'granted') {
        setLocationGranted(true);
        return;
      }
      // Try requesting again (works if never asked before)
      const { status: newStatus } = await Location.requestForegroundPermissionsAsync();
      if (newStatus === 'granted') {
        setLocationGranted(true);
      } else {
        setLocationGranted(false);
        Alert.alert(
          '📍 Location needed',
          'Without location access, we search from a default city and may show no workers near you.\n\nGo to Settings → Apps → sthapna.ai → Permissions → Location → Allow.',
          [
            { text: 'Open Settings', onPress: () => Linking.openSettings() },
            { text: 'Continue anyway', style: 'cancel' },
          ],
        );
      }
    })();
  }, []);

  const navWidth = trayAnim.interpolate({ inputRange: [0, 1], outputRange: [56, Math.min(SW - 24, 366)] });
  const navHeight = trayAnim.interpolate({ inputRange: [0, 1], outputRange: [56, 68] });
  const navRadius = trayAnim.interpolate({ inputRange: [0, 1], outputRange: [28, 28] });
  const navBg = trayAnim.interpolate({
    inputRange: [0, 1],
    outputRange: ['rgba(255,255,255,0.16)', 'rgba(255,255,255,0.90)'],
  });

  // ─── Data fetch ─────────────────────────────────────────────────────────────

  const loadFeed = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const list = await workerService.fetchExplore({
        trade: activeCategory === 'All' ? undefined : activeCategory,
        radiusKm: radius,
      });
      setWorkers(list);
      setCurrentIndex(0);
    } catch (e) {
      setError(e.message || 'Could not load workers');
      setWorkers([]);
    } finally {
      setLoading(false);
    }
  }, [activeCategory, radius]);

  useEffect(() => { loadFeed(); }, [loadFeed]);

  // Guard against out-of-range index (e.g. after stale swipe state).
  useEffect(() => {
    if (workers.length === 0) return;
    if (currentIndex < 0 || currentIndex >= workers.length) {
      setCurrentIndex(0);
    }
  }, [workers.length, currentIndex]);

  const worker = workers[currentIndex] ?? null;

  useEffect(() => {
    if (!worker?.id) return;
    workerService.fetchMyActionState(worker.id).then(s => {
      setActionStates(prev => ({ ...prev, [worker.id]: s }));
    }).catch(() => {});
  }, [worker?.id]);

  const snap = actionStates[worker?.id] || {};
  const liked  = snap?.has_liked  ?? false;
  const saved  = snap?.has_saved  ?? false;
  const vouched = snap?.has_vouched ?? false;

  // PanResponder is created once — keep workers length in a ref (stale closure fix).
  const workersRef = useRef(workers);
  workersRef.current = workers;

  // ─── Swipe gesture (vertical) ────────────────────────────────────────────────

  const panRef = useRef(
    PanResponder.create({
      // Only steal the gesture if vertical movement is dominant
      onMoveShouldSetPanResponder: (_, gs) =>
        Math.abs(gs.dy) > Math.abs(gs.dx) && Math.abs(gs.dy) > 12,
      onPanResponderRelease: (_, gs) => {
        const count = workersRef.current.length;
        if (count === 0) return;
        if (gs.dy < -50) {
          setCurrentIndex(i => Math.min(i + 1, count - 1));
        } else if (gs.dy > 50) {
          setCurrentIndex(i => Math.max(i - 1, 0));
        }
      },
    }),
  ).current;

  // ─── Render ──────────────────────────────────────────────────────────────────

  const decreaseRadius = () => setRadius(r => Math.max(1, r - 1));
  const increaseRadius = () => setRadius(r => Math.min(50, r + 1));

  const bgColors = worker
    ? [worker.gradientStartHex || '#1a1a2e', worker.gradientEndHex || '#16213e']
    : ['#111111', '#111111'];
  const hasReelVideo = worker && !!explorePlaybackSource(worker);

  return (
    <View style={s.root}>
      <StatusBar style="light" />

      {/* Reel video (when URL available) or gradient fallback */}
      {hasReelVideo ? (
        <ExploreReelPlayer worker={worker} />
      ) : (
        <LinearGradient colors={bgColors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={StyleSheet.absoluteFill} />
      )}

      {hasReelVideo && (
        <View style={[StyleSheet.absoluteFill, s.videoScrim]} pointerEvents="none" />
      )}

      {/* Vignette overlay (top dark → clear → clear → bottom dark) */}
      <LinearGradient
        colors={['rgba(0,0,0,0.5)', 'transparent', 'transparent', 'rgba(0,0,0,0.82)']}
        start={{ x: 0, y: 0 }} end={{ x: 0, y: 1 }}
        style={StyleSheet.absoluteFill}
        pointerEvents="none"
      />

      <SafeAreaView edges={['top']} style={{ flex: 1 }}>
        {/* ── Top controls ── */}
        <View style={s.topContainer}>
          {/* Top bar: back | progress dots | radius pill */}
          <View style={s.topBar}>
            <PressScale onPress={onBack} style={s.backBtn}>
              <Text style={s.backBtnText}>←</Text>
            </PressScale>

            {/* Progress dots */}
            <View style={s.progressContainer}>
              {workers.length > 0 ? (
                workers.map((w, i) => (
                  <Pressable key={w.id ?? i} onPress={() => setCurrentIndex(i)}>
                    <View style={[
                      s.progressDot,
                      i === currentIndex && { backgroundColor: '#fff', width: 22, borderRadius: 3 },
                    ]} />
                  </Pressable>
                ))
              ) : (
                <Text style={s.noWorkersTxt}>{t('No workers found', 'कोई कामगार नहीं मिला')}</Text>
              )}
            </View>

            {/* Radius pill */}
            <View style={s.radiusPill}>
              <Pressable onPress={decreaseRadius} style={s.radiusBtn} hitSlop={8}>
                <Text style={s.radiusBtnText}>−</Text>
              </Pressable>
              <View style={s.radiusCenter}>
                <Text style={s.radiusIcon}>📍</Text>
                <Text style={s.radiusText}>{radius} km</Text>
              </View>
              <Pressable onPress={increaseRadius} style={s.radiusBtn} hitSlop={8}>
                <Text style={s.radiusBtnText}>+</Text>
              </Pressable>
            </View>
          </View>

          {/* Category filter bar — horizontal ScrollView (does NOT steal vertical pan) */}
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={s.categoryScroll}
            keyboardShouldPersistTaps="handled"
            // Explicitly allow horizontal scroll even inside PanResponder container
            scrollEventThrottle={16}
          >
            {AllCategories.map(cat => {
              const on = cat === activeCategory;
              return (
                <PressScale key={cat} onPress={() => { setActiveCategory(cat); setCurrentIndex(0); }}>
                  <View style={[s.categoryChip, on && { backgroundColor: accent, borderColor: accent }]}>
                    <Text style={[s.categoryChipText, on && { color: '#fff' }]}>{cat}</Text>
                  </View>
                </PressScale>
              );
            })}
          </ScrollView>

          <Text style={s.swipeHint}>{t('↕ swipe to browse', '↕ ब्राउज़ करने के लिए स्वाइप करें')}</Text>

          {/* Location denied warning */}
          {locationGranted === false && (
            <Pressable onPress={() => Linking.openSettings()} style={s.locationBanner}>
              <Text style={s.locationBannerText}>
                📍 {t('Location denied — results may be from the wrong city. Tap to fix.', 'लोकेशन बंद है — परिणाम गलत शहर के हो सकते हैं। ठीक करने के लिए टैप करें।')}
              </Text>
            </Pressable>
          )}
        </View>

        {/* ── Worker content area (swipeable) ── */}
        {loading ? (
          <View style={s.centerBox}>
            <ActivityIndicator size="large" color="#fff" />
            <Text style={s.loadingText}>{t('Finding workers...', 'कामगार ढूंढ रहे हैं...')}</Text>
          </View>
        ) : error ? (
          <View style={s.centerBox}>
            <Text style={s.emptyIcon}>📡</Text>
            <Text style={s.emptyTitle}>{t("Couldn't reach the server", 'सर्वर से कनेक्ट नहीं')}</Text>
            <Text style={s.emptySubtitle}>{error}</Text>
            <PressScale onPress={loadFeed} style={[s.retryBtn, { backgroundColor: accent }]}>
              <Text style={s.retryBtnText}>{t('Try again', 'फिर कोशिश करें')}</Text>
            </PressScale>
          </View>
        ) : !worker ? (
          <View style={s.centerBox}>
            <Text style={s.emptyIcon}>🔍</Text>
            <Text style={s.emptyTitle}>{t(`No workers in ${radius} km`, `${radius} km में कोई कामगार नहीं`)}</Text>
            <Text style={s.emptySubtitle}>{t('Try increasing the radius above', 'ऊपर से दूरी बढ़ाएं')}</Text>
          </View>
        ) : (
          /* Wrap in View with panHandlers for vertical swipe */
          <View style={s.workerArea} {...panRef.panHandlers}>
            {/* Avatar / vouch — emoji fallback when no reel video */}
            <View style={s.avatarBlock}>
              {!hasReelVideo && (
                <View style={s.avatarCircle}>
                  <Text style={s.avatarEmoji}>{worker.emoji}</Text>
                </View>
              )}
              <View style={s.vouchBadge}>
                <Text style={s.vouchStar}>★</Text>
                <Text style={s.vouchText}>{worker.vouchScore ?? 0} Vouched</Text>
              </View>
            </View>

            {/* Bottom: worker info + action column */}
            <View style={[s.bottomBlock, { paddingBottom: insets.bottom + 96 }]}>
              {/* Left: worker info */}
              <View style={s.workerInfo}>
                {/* Name row */}
                <View style={s.nameRow}>
                  <LinearGradient
                    colors={[worker.gradientStartHex || '#fff', accent]}
                    start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }}
                    style={s.initialsBox}
                  >
                    <Text style={s.initialsText}>{initials(worker.name)}</Text>
                  </LinearGradient>
                  <View>
                    <Text style={s.nameText} numberOfLines={1}>{worker.name}</Text>
                    <Text style={s.tradeText} numberOfLines={1}>{worker.trade}</Text>
                  </View>
                </View>

                {/* Location */}
                <View style={s.locationRow}>
                  <Text style={s.locationIcon}>📍</Text>
                  <Text style={s.locationText}>{worker.location}</Text>
                </View>

                {/* Tag pills */}
                <View style={s.tagsRow}>
                  {(worker.tags || []).map(tag => (
                    <View key={tag} style={s.tagPill}>
                      <Text style={s.tagPillText}>#{tag}</Text>
                    </View>
                  ))}
                </View>

                {/* Stats inline */}
                <View style={s.statsRow}>
                  <Text style={s.statVal}>{worker.rating}★</Text>
                  <Text style={s.statLbl}> Rating</Text>
                  <View style={{ width: 12 }} />
                  <Text style={s.statVal}>{worker.jobs}</Text>
                  <Text style={s.statLbl}> Jobs</Text>
                </View>

                {/* View Profile button — matches iOS accent rounded rect */}
                <PressScale
                  onPress={() => onViewProfile(worker)}
                  style={[s.viewProfileBtn, { backgroundColor: accent, shadowColor: accent }]}
                >
                  <Text style={s.viewProfileText}>{t('View Profile', 'प्रोफ़ाइल देखें')} →</Text>
                </PressScale>
              </View>

              {/* Right: action column */}
              <View style={s.actionColumn}>
                <ActionBtn
                  icon={liked ? '♥' : '♡'}
                  label={String(snap?.counts?.likes ?? 0)}
                  tint={liked ? '#E63946' : '#fff'}
                  onPress={async () => {
                    liked ? await workerService.unlike(worker.id) : await workerService.like(worker.id);
                    setActionStates(p => ({ ...p, [worker.id]: { ...p[worker.id], has_liked: !liked } }));
                  }}
                />
                <ActionBtn icon="💬" label={String(snap?.counts?.messages ?? 0)} />
                <ActionBtn icon="↗" />
                <ActionBtn
                  icon={saved ? '🔖' : '📑'}
                  tint={saved ? '#F4A261' : '#fff'}
                  onPress={async () => {
                    saved ? await workerService.unsave(worker.id) : await workerService.save(worker.id);
                    setActionStates(p => ({ ...p, [worker.id]: { ...p[worker.id], has_saved: !saved } }));
                  }}
                />
                <ActionBtn
                  icon={vouched ? '✦' : '★'}
                  label={t(vouched ? 'Vouched' : 'Vouch', vouched ? 'Vouch किया' : 'Vouch')}
                  tint={vouched ? '#3B82F6' : '#fff'}
                />
              </View>
            </View>
          </View>
        )}
      </SafeAreaView>

      {/* ── Morphing nav (bottom-right corner, fixed) ── */}
      <Animated.View
        style={[
          s.morphOuter,
          {
            bottom: insets.bottom + 20,
            width: navWidth,
            height: navHeight,
            borderRadius: navRadius,
            backgroundColor: navBg,
            borderColor: trayOpen ? 'rgba(255,255,255,0.95)' : 'rgba(255,255,255,0.36)',
          },
        ]}
      >
        {trayOpen ? (
          /* Expanded tab bar */
          <View style={s.expandedInner}>
            <TabTile icon="🏠" label={t('Home', 'होम')} onPress={onGoProfile} />
            <TabTile icon="🔍" label={t('Explore', 'एक्सप्लोर')} active accent={accent} onPress={() => setTrayOpen(false)} />
            <PressScale onPress={() => setTrayOpen(false)} style={[s.navPlusBtn, { backgroundColor: accent }]}>
              <Text style={s.navPlusTxt}>+</Text>
            </PressScale>
            <TabTile icon="👤" label={t('Profile', 'प्रोफ़ाइल')} onPress={onGoProfile} />
            <TabTile icon="💬" label={t('Messages', 'संदेश')} onPress={() => setTrayOpen(false)} />
          </View>
        ) : (
          /* Collapsed hamburger circle */
          <Pressable onPress={() => setTrayOpen(true)} style={s.collapsedBtn}>
            <Text style={s.collapsedIcon}>☰</Text>
          </Pressable>
        )}
      </Animated.View>
    </View>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#000' },
  videoScrim: { backgroundColor: 'rgba(0,0,0,0.28)' },

  // Top controls
  topContainer: { paddingTop: 6 },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    justifyContent: 'space-between',
    gap: 10,
  },
  backBtn: {
    width: 36, height: 36, borderRadius: 12,
    backgroundColor: 'rgba(255,255,255,0.12)',
    borderWidth: 1, borderColor: 'rgba(255,255,255,0.20)',
    alignItems: 'center', justifyContent: 'center',
  },
  backBtnText: { color: '#fff', fontSize: 18, fontWeight: 'bold' },

  progressContainer: {
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 5,
  },
  progressDot: {
    height: 6, width: 6, borderRadius: 3,
    backgroundColor: 'rgba(255,255,255,0.30)',
  },
  noWorkersTxt: { color: 'rgba(255,255,255,0.45)', fontSize: 12 },

  locationBanner: {
    marginHorizontal: 16,
    marginTop: 6,
    backgroundColor: 'rgba(238,108,77,0.22)',
    borderWidth: 1,
    borderColor: 'rgba(238,108,77,0.40)',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 7,
  },
  locationBannerText: {
    color: '#ffcbb8',
    fontSize: 11,
    fontWeight: '600',
    textAlign: 'center',
  },

  radiusPill: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.12)',
    borderWidth: 1, borderColor: 'rgba(255,255,255,0.20)',
    borderRadius: 20,
  },
  radiusBtn: { paddingHorizontal: 12, paddingVertical: 7 },
  radiusBtnText: { color: '#fff', fontSize: 18, fontWeight: 'bold' },
  radiusCenter: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  radiusIcon: { fontSize: 11 },
  radiusText: { color: '#fff', fontSize: 12, fontWeight: '800' },

  categoryScroll: { paddingHorizontal: 16, paddingTop: 10, gap: 8, paddingBottom: 2 },
  categoryChip: {
    paddingHorizontal: 14, paddingVertical: 7,
    borderRadius: 20,
    backgroundColor: 'rgba(255,255,255,0.14)',
    borderWidth: 1, borderColor: 'rgba(255,255,255,0.20)',
  },
  categoryChipText: { color: 'rgba(255,255,255,0.75)', fontSize: 12, fontWeight: 'bold' },

  swipeHint: {
    textAlign: 'center',
    color: 'rgba(255,255,255,0.60)',
    fontSize: 11, fontWeight: '500',
    marginTop: 8,
  },

  // States
  centerBox: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 12 },
  loadingText: { color: 'rgba(255,255,255,0.65)', fontSize: 13, marginTop: 14 },
  emptyIcon: { fontSize: 40, opacity: 0.5 },
  emptyTitle: { color: '#fff', fontSize: 16, fontWeight: '800' },
  emptySubtitle: { color: 'rgba(255,255,255,0.50)', fontSize: 13, textAlign: 'center', paddingHorizontal: 40 },
  retryBtn: { paddingHorizontal: 18, paddingVertical: 8, borderRadius: 20 },
  retryBtnText: { color: '#fff', fontSize: 13, fontWeight: 'bold' },

  // Worker content
  workerArea: {
    flex: 1,
    justifyContent: 'space-between',
  },
  avatarBlock: { alignItems: 'center', marginTop: 20, gap: 12 },
  avatarCircle: {
    width: 110, height: 110, borderRadius: 55,
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderWidth: 2, borderColor: 'rgba(255,255,255,0.18)',
    alignItems: 'center', justifyContent: 'center',
  },
  avatarEmoji: { fontSize: 54 },
  vouchBadge: {
    flexDirection: 'row', alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.12)',
    borderWidth: 1, borderColor: 'rgba(255,255,255,0.20)',
    borderRadius: 20, paddingHorizontal: 14, paddingVertical: 4, gap: 6,
  },
  vouchStar: { color: '#fff', fontSize: 11 },
  vouchText: { color: 'rgba(255,255,255,0.90)', fontSize: 12, fontWeight: '800' },

  bottomBlock: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    paddingHorizontal: 18,
    gap: 16,
  },
  workerInfo: { flex: 1 },

  nameRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  initialsBox: {
    width: 40, height: 40, borderRadius: 13,
    borderWidth: 1.5, borderColor: 'rgba(255,255,255,0.20)',
    alignItems: 'center', justifyContent: 'center',
  },
  initialsText: { color: '#fff', fontSize: 14, fontWeight: '800' },
  nameText: { color: '#fff', fontSize: 18, fontWeight: '800' },
  tradeText: { color: 'rgba(255,255,255,0.65)', fontSize: 13 },

  locationRow: { flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 6 },
  locationIcon: { fontSize: 11 },
  locationText: { color: 'rgba(255,255,255,0.50)', fontSize: 12 },

  tagsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginTop: 8 },
  tagPill: {
    backgroundColor: 'rgba(255,255,255,0.12)',
    borderWidth: 1, borderColor: 'rgba(255,255,255,0.20)',
    borderRadius: 20, paddingHorizontal: 10, paddingVertical: 3,
  },
  tagPillText: { color: 'rgba(255,255,255,0.75)', fontSize: 11, fontWeight: '600' },

  statsRow: { flexDirection: 'row', alignItems: 'center', marginTop: 10 },
  statVal: { color: '#fff', fontSize: 14, fontWeight: '800' },
  statLbl: { color: 'rgba(255,255,255,0.45)', fontSize: 12 },

  viewProfileBtn: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center',
    paddingVertical: 13, paddingHorizontal: 22,
    borderRadius: 14, marginTop: 14,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.44, shadowRadius: 8,
    elevation: 6,
  },
  viewProfileText: { color: '#fff', fontSize: 14, fontWeight: 'bold' },

  // Action column
  actionColumn: { gap: 16, paddingBottom: 4 },
  actionTile: { alignItems: 'center', gap: 4 },
  actionCircle: {
    width: 46, height: 46, borderRadius: 23,
    backgroundColor: 'rgba(255,255,255,0.12)',
    borderWidth: 1, borderColor: 'rgba(255,255,255,0.20)',
    alignItems: 'center', justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.30, shadowRadius: 6,
    elevation: 4,
  },
  actionIcon: { fontSize: 18 },
  actionLabel: { color: 'rgba(255,255,255,0.75)', fontSize: 10, fontWeight: '600' },

  // Morphing nav
  morphOuter: {
    position: 'absolute',
    right: 12,
    overflow: 'hidden',
    borderWidth: 1.5,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.45, shadowRadius: 16,
    elevation: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  collapsedBtn: {
    width: 56, height: 56,
    alignItems: 'center', justifyContent: 'center',
  },
  collapsedIcon: {
    color: 'rgba(255,255,255,0.92)',
    fontSize: 22, fontWeight: '600',
  },
  expandedInner: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
  },
  tabTile: {
    flex: 1, alignItems: 'center', justifyContent: 'center',
    paddingVertical: 6, gap: 3,
  },
  tabTileIcon: { fontSize: 19, color: 'rgba(39,41,50,0.30)' },
  tabTileLabel: { fontSize: 10, fontWeight: 'bold', color: Colors.dimText },
  navPlusBtn: {
    width: 44, height: 44, borderRadius: 22,
    alignItems: 'center', justifyContent: 'center',
    marginHorizontal: 8,
  },
  navPlusTxt: { color: '#fff', fontSize: 20, fontWeight: 'bold' },
});
