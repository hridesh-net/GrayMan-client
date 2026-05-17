import React, { useState, useRef, useMemo, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  PanResponder,
  TouchableOpacity,
  Dimensions,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { LinearGradient } from 'expo-linear-gradient';
import { BlurView } from 'expo-blur';

import { useTheme } from '../src/AppTheme';
import Blobs from '../src/components/Blobs';
import PressScale from '../src/components/PressScale';
import { AllCategories } from '../src/workers';
import { workerService } from '../src/api/workerService';
import { Colors, Radius, Shadow } from '../src/theme';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

// ---------------------------------------------------------------------------
// ExploreScreen
// ---------------------------------------------------------------------------
export default function ExploreScreen({ onBack, onViewProfile, onGoProfile }) {
  const { accent, t } = useTheme();
  const insets = useSafeAreaInsets();

  const [radius, setRadius] = useState(5);
  const [activeCategory, setActiveCategory] = useState('All');
  const [currentIndex, setCurrentIndex] = useState(0);
  const [workers, setWorkers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [liked, setLiked] = useState(false);
  const [saved, setSaved] = useState(false);

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

  useEffect(() => {
    loadFeed();
  }, [loadFeed]);

  const filtered = workers;

  // Reset card index when filter changes.
  const prevCategory = useRef(activeCategory);
  if (prevCategory.current !== activeCategory) {
    prevCategory.current = activeCategory;
    // Safe to mutate during render (index will be 0 after this branch).
    // We use a ref trick to avoid stale closure issues without an effect.
  }

  const safeIndex = Math.min(currentIndex, Math.max(filtered.length - 1, 0));
  const worker = filtered[safeIndex];

  useEffect(() => {
    if (!worker?.id) return;
    workerService.fetchMyActionState(worker.id).then(s => {
      setLiked(s?.has_liked ?? false);
      setSaved(s?.has_saved ?? false);
    }).catch(() => {});
  }, [worker?.id]);

  // -------------------------------------------------------------------------
  // PanResponder — left/right advances index, up/down also advances (vertical
  // swipe feel matching the spec).
  // -------------------------------------------------------------------------
  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: (_, gs) =>
        Math.abs(gs.dx) > 8 || Math.abs(gs.dy) > 8,
      onPanResponderRelease: (_, gs) => {
        const horizontal = Math.abs(gs.dx) > Math.abs(gs.dy);
        if (horizontal) {
          // Swipe left → next; swipe right → previous.
          if (gs.dx < -30) {
            setCurrentIndex(prev =>
              prev < filtered.length - 1 ? prev + 1 : prev,
            );
          } else if (gs.dx > 30) {
            setCurrentIndex(prev => (prev > 0 ? prev - 1 : prev));
          }
        } else {
          // Swipe up → next; swipe down → previous.
          if (gs.dy < -30) {
            setCurrentIndex(prev =>
              prev < filtered.length - 1 ? prev + 1 : prev,
            );
          } else if (gs.dy > 30) {
            setCurrentIndex(prev => (prev > 0 ? prev - 1 : prev));
          }
        }
      },
    }),
  ).current;

  // -------------------------------------------------------------------------
  // Radius helpers
  // -------------------------------------------------------------------------
  const decreaseRadius = () => setRadius(r => Math.max(1, r - 1));
  const increaseRadius = () => setRadius(r => Math.min(50, r + 1));

  // -------------------------------------------------------------------------
  // Category change helper — also resets card index.
  // -------------------------------------------------------------------------
  const handleCategoryChange = cat => {
    setActiveCategory(cat);
    setCurrentIndex(0);
  };

  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <StatusBar style="dark" />
      <Blobs accent={accent} opacity={0.45} />

      {/* ------------------------------------------------------------------ */}
      {/* HEADER                                                              */}
      {/* ------------------------------------------------------------------ */}
      <View style={[styles.header, { paddingTop: insets.top > 0 ? 8 : 16 }]}>
        {/* Back button */}
        <PressScale onPress={onBack} style={styles.iconBtn}>
          <Text style={styles.iconBtnText}>←</Text>
        </PressScale>

        {/* Radius control */}
        <View style={styles.radiusRow}>
          <PressScale onPress={decreaseRadius} style={styles.iconBtn}>
            <Text style={styles.iconBtnText}>−</Text>
          </PressScale>

          <View style={styles.radiusPill}>
            <Text style={styles.radiusPillText}>{radius} km</Text>
          </View>

          <PressScale onPress={increaseRadius} style={styles.iconBtn}>
            <Text style={styles.iconBtnText}>+</Text>
          </PressScale>
        </View>

        {/* Own-profile avatar */}
        <PressScale onPress={onGoProfile} style={styles.avatarBtn}>
          <LinearGradient
            colors={[Colors.shadowGrey, accent]}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.avatarGradient}
          >
            <Text style={styles.avatarInitial}>Y</Text>
          </LinearGradient>
        </PressScale>
      </View>

      {/* ------------------------------------------------------------------ */}
      {/* CATEGORY FILTER CHIPS                                               */}
      {/* ------------------------------------------------------------------ */}
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.categoryList}
        style={styles.categoryScroll}
      >
        {AllCategories.map(cat => {
          const selected = cat === activeCategory;
          return (
            <PressScale key={cat} onPress={() => handleCategoryChange(cat)}>
              <View
                style={[
                  styles.categoryChip,
                  selected
                    ? { backgroundColor: accent }
                    : { backgroundColor: Colors.soft },
                ]}
              >
                <Text
                  style={[
                    styles.categoryChipText,
                    { color: selected ? '#fff' : Colors.shadowGrey },
                  ]}
                >
                  {cat}
                </Text>
              </View>
            </PressScale>
          );
        })}
      </ScrollView>

      {/* ------------------------------------------------------------------ */}
      {/* WORKER CARD AREA                                                    */}
      {/* ------------------------------------------------------------------ */}
      {loading ? (
        <View style={styles.loadingBox}>
          <ActivityIndicator size="large" color={accent} />
        </View>
      ) : filtered.length === 0 ? (
        <EmptyState radius={radius} t={t} message={error} />
      ) : (
        <View style={styles.cardArea} {...panResponder.panHandlers}>
          <WorkerCard
            worker={worker}
            accent={accent}
            onViewProfile={() => onViewProfile(worker)}
          />

          {/* Swipe hint — only on first card */}
          {safeIndex === 0 && (
            <Text style={styles.swipeHint}>
              {t('↕ swipe to browse', '↕ ब्राउज़ करने के लिए स्वाइप करें')}
            </Text>
          )}

          {/* Dot pagination */}
          <View style={styles.pagination}>
            {filtered.map((_, i) => (
              <View
                key={i}
                style={[
                  styles.dot,
                  i === safeIndex
                    ? { backgroundColor: accent, width: 16 }
                    : { backgroundColor: Colors.dimText },
                ]}
              />
            ))}
          </View>
        </View>
      )}

      {/* ------------------------------------------------------------------ */}
      {/* ACTION ROW                                                          */}
      {/* ------------------------------------------------------------------ */}
      <View style={styles.actionRow}>
        {ACTION_BUTTONS.map(btn => (
          <PressScale
            key={btn.label}
            style={styles.actionBtn}
            onPress={async () => {
              if (!worker?.id) return;
              try {
                if (btn.id === 'like') {
                  if (liked) {
                    await workerService.unlike(worker.id);
                    setLiked(false);
                  } else {
                    await workerService.like(worker.id);
                    setLiked(true);
                  }
                } else if (btn.id === 'save') {
                  if (saved) {
                    await workerService.unsave(worker.id);
                    setSaved(false);
                  } else {
                    await workerService.save(worker.id);
                    setSaved(true);
                  }
                } else if (btn.id === 'message') {
                  await workerService.sendMessage(worker.id, 'Hi, I saw your profile on GrayMan.');
                } else if (btn.id === 'vouch') {
                  onViewProfile(worker);
                }
              } catch { /* ignore */ }
            }}
          >
            <Text style={styles.actionBtnIcon}>{btn.icon}</Text>
          </PressScale>
        ))}
      </View>

      {/* ------------------------------------------------------------------ */}
      {/* BOTTOM TAB BAR                                                      */}
      {/* ------------------------------------------------------------------ */}
      <BlurView
        intensity={90}
        tint="light"
        style={[styles.tabBar, { marginBottom: insets.bottom > 0 ? 0 : 20 }]}
      >
        {TAB_ITEMS.map(tab => {
          const active = tab.id === 'explore';
          return (
            <TouchableOpacity
              key={tab.id}
              style={styles.tabItem}
              onPress={tab.id === 'profile' ? onGoProfile : undefined}
              activeOpacity={0.7}
            >
              <Text
                style={[
                  styles.tabIcon,
                  { color: active ? accent : 'rgba(39,41,50,0.35)' },
                ]}
              >
                {tab.icon}
              </Text>
              <Text
                style={[
                  styles.tabLabel,
                  { color: active ? accent : Colors.dimText },
                ]}
              >
                {tab.label}
              </Text>
            </TouchableOpacity>
          );
        })}
      </BlurView>
    </SafeAreaView>
  );
}

// ---------------------------------------------------------------------------
// WorkerCard
// ---------------------------------------------------------------------------
function WorkerCard({ worker, accent, onViewProfile }) {
  return (
    <View style={styles.card}>
      <LinearGradient
        colors={[Colors.shadowGrey, worker.gradientEndHex]}
        start={{ x: 0, y: 0 }}
        end={{ x: 0.6, y: 1 }}
        style={StyleSheet.absoluteFill}
        borderRadius={24}
      />

      {/* Top badges */}
      <View style={styles.cardBadgeRow}>
        <View style={styles.distanceBadge}>
          <Text style={styles.distanceBadgeText}>{worker.distance} km</Text>
        </View>
        <View style={[styles.vouchBadge, { backgroundColor: accent }]}>
          <Text style={styles.vouchBadgeText}>{worker.vouchScore} ✓ Vouched</Text>
        </View>
      </View>

      {/* Center initials */}
      <View style={styles.initialsWrap}>
        <Text style={styles.initialsText}>{worker.initials}</Text>
      </View>

      {/* Bottom info card */}
      <View style={styles.infoCard}>
        <Text style={styles.workerName}>{worker.name}</Text>
        <Text style={styles.workerTrade}>{worker.trade}</Text>

        <View style={styles.locationRow}>
          <Text style={styles.locationPin}>📍</Text>
          <Text style={styles.locationText}>{worker.location}</Text>
        </View>

        <View style={styles.statsRow}>
          <Text style={styles.ratingText}>⭐ {worker.rating}</Text>
          <Text style={styles.jobsText}>{worker.jobs} jobs</Text>
        </View>

        {/* First 3 tags */}
        <View style={styles.tagsRow}>
          {worker.tags.slice(0, 3).map(tag => (
            <View key={tag} style={styles.tagChip}>
              <Text style={styles.tagText}>{tag}</Text>
            </View>
          ))}
        </View>

        {/* View Profile CTA */}
        <PressScale
          onPress={onViewProfile}
          style={[styles.viewProfileBtn, { backgroundColor: accent, shadowColor: accent }]}
        >
          <Text style={styles.viewProfileText}>View Profile →</Text>
        </PressScale>
      </View>
    </View>
  );
}

// ---------------------------------------------------------------------------
// EmptyState
// ---------------------------------------------------------------------------
function EmptyState({ radius, t, message }) {
  return (
    <View style={styles.emptyState}>
      <Text style={styles.emptyTitle}>
        {message || t(`No workers in ${radius} km`, `${radius} km में कोई कामगार नहीं`)}
      </Text>
      <Text style={styles.emptySubtitle}>
        {t(
          'Try increasing the radius above',
          'ऊपर दायरा बढ़ाने की कोशिश करें',
        )}
      </Text>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Static data
// ---------------------------------------------------------------------------
const ACTION_BUTTONS = [
  { id: 'like',    label: 'Like',    icon: '♡' },
  { id: 'message', label: 'Message', icon: '💬' },
  { id: 'share',   label: 'Share',   icon: '↑' },
  { id: 'vouch',   label: 'Vouch',   icon: '✓' },
];

const TAB_ITEMS = [
  { id: 'home',     icon: '🏠', label: 'Home'     },
  { id: 'explore',  icon: '🔍', label: 'Explore'  },
  { id: 'profile',  icon: '👤', label: 'Profile'  },
  { id: 'messages', icon: '💬', label: 'Messages' },
];

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
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingBottom: 10,
  },
  iconBtn: {
    width: 36,
    height: 36,
    borderRadius: Radius.md,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconBtnText: {
    fontSize: 16,
    color: Colors.shadowGrey,
    fontWeight: '600',
  },
  radiusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  radiusPill: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: Radius.full,
    backgroundColor: Colors.soft,
    minWidth: 64,
    alignItems: 'center',
  },
  radiusPillText: {
    fontSize: 14,
    fontWeight: '700',
    color: Colors.shadowGrey,
  },
  avatarBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    overflow: 'hidden',
  },
  avatarGradient: {
    width: 36,
    height: 36,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarInitial: {
    fontSize: 14,
    fontWeight: '800',
    color: '#fff',
  },

  // Category filter
  categoryScroll: {
    flexGrow: 0,
    marginBottom: 8,
  },
  categoryList: {
    paddingHorizontal: 20,
    gap: 8,
    alignItems: 'center',
  },
  categoryChip: {
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  categoryChipText: {
    fontSize: 13,
    fontWeight: '600',
  },

  // Card area
  cardArea: {
    flex: 1,
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingBottom: 4,
  },
  card: {
    flex: 1,
    width: '100%',
    borderRadius: 24,
    overflow: 'hidden',
    ...Shadow.card,
  },
  cardBadgeRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: 16,
    paddingBottom: 0,
  },
  distanceBadge: {
    backgroundColor: 'rgba(255,255,255,0.92)',
    borderRadius: Radius.full,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  distanceBadgeText: {
    fontSize: 13,
    fontWeight: '700',
    color: Colors.shadowGrey,
  },
  vouchBadge: {
    borderRadius: Radius.full,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  vouchBadgeText: {
    fontSize: 13,
    fontWeight: '700',
    color: '#fff',
  },

  // Center initials
  initialsWrap: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  initialsText: {
    fontSize: 72,
    fontWeight: '800',
    color: 'rgba(255,255,255,0.90)',
    letterSpacing: -2,
  },

  // Bottom info card
  infoCard: {
    backgroundColor: 'rgba(255,255,255,0.94)',
    borderRadius: 20,
    margin: 12,
    padding: 16,
  },
  workerName: {
    fontSize: 20,
    fontWeight: '800',
    color: Colors.shadowGrey,
    letterSpacing: -0.5,
    marginBottom: 2,
  },
  workerTrade: {
    fontSize: 14,
    color: Colors.mutedText,
    marginBottom: 8,
  },
  locationRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginBottom: 6,
  },
  locationPin: {
    fontSize: 12,
  },
  locationText: {
    fontSize: 13,
    color: Colors.mutedText,
  },
  statsRow: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 10,
    alignItems: 'center',
  },
  ratingText: {
    fontSize: 13,
    fontWeight: '600',
    color: Colors.shadowGrey,
  },
  jobsText: {
    fontSize: 13,
    color: Colors.mutedText,
  },
  tagsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
    marginBottom: 14,
  },
  tagChip: {
    backgroundColor: Colors.soft,
    borderRadius: Radius.full,
    paddingHorizontal: 10,
    paddingVertical: 4,
  },
  tagText: {
    fontSize: 12,
    fontWeight: '500',
    color: Colors.shadowGrey,
  },
  viewProfileBtn: {
    borderRadius: Radius.md,
    paddingVertical: 12,
    alignItems: 'center',
    ...Shadow.button,
  },
  viewProfileText: {
    fontSize: 15,
    fontWeight: '700',
    color: '#fff',
  },

  // Swipe hint
  swipeHint: {
    marginTop: 8,
    fontSize: 12,
    color: Colors.dimText,
    textAlign: 'center',
  },

  // Pagination dots
  pagination: {
    flexDirection: 'row',
    gap: 6,
    marginTop: 10,
    alignItems: 'center',
  },
  dot: {
    height: 6,
    borderRadius: 3,
    width: 6,
  },

  // Action row
  actionRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 20,
    paddingVertical: 12,
    paddingHorizontal: 20,
  },
  actionBtn: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: Colors.soft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  actionBtnIcon: {
    fontSize: 20,
    color: Colors.shadowGrey,
  },

  // Bottom tab bar
  tabBar: {
    flexDirection: 'row',
    marginHorizontal: 12,
    marginBottom: 20,
    borderRadius: 24,
    paddingVertical: 10,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.90)',
  },
  tabItem: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 2,
  },
  tabIcon: {
    fontSize: 20,
  },
  tabLabel: {
    fontSize: 10,
    fontWeight: '700',
  },

  // Empty state
  loadingBox: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 40,
  },
  emptyTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: Colors.shadowGrey,
    textAlign: 'center',
    marginBottom: 8,
  },
  emptySubtitle: {
    fontSize: 14,
    color: Colors.mutedText,
    textAlign: 'center',
  },
});
