import React, { useEffect, useMemo, useRef } from 'react';
import { StyleSheet, View } from 'react-native';
import { useVideoPlayer, VideoView } from 'expo-video';

/**
 * Pick HLS master or MP4 reel URL — mirrors iOS ReelPlayerView preference.
 */
export function explorePlaybackSource(worker) {
  if (!worker) return null;

  const candidates = [
    worker.reelHlsUrl,
    worker.playbackUrl,
    worker.reelUrl,
  ].filter(Boolean);

  for (const raw of candidates) {
    const uri = String(raw).trim();
    if (!uri) continue;
    const lower = uri.toLowerCase();
    if (lower.includes('.m3u8') || lower.includes('/hls/')) {
      return { uri, contentType: 'hls' };
    }
    return { uri };
  }
  return null;
}

/** Full-bleed reel player for Explore (video + audio). */
export default function ExploreReelPlayer({ worker }) {
  const source = useMemo(
    () => explorePlaybackSource(worker),
    [worker?.id, worker?.reelHlsUrl, worker?.playbackUrl, worker?.reelUrl],
  );

  const player = useVideoPlayer(source, p => {
    p.loop = true;
    p.muted = false;
    if (source) p.play();
  });

  // Swap source on swipe — do NOT remount (key) or call pause() on unmount;
  // expo-video releases the native player before JS cleanup runs on Android.
  const mountedWorkerId = useRef(worker?.id);

  useEffect(() => {
    if (worker?.id === mountedWorkerId.current) return;
    mountedWorkerId.current = worker?.id;

    const next = explorePlaybackSource(worker);
    if (!next) return;

    let cancelled = false;
    player.replaceAsync(next).then(() => {
      if (cancelled) return;
      player.loop = true;
      player.muted = false;
      player.play();
    }).catch(() => {});

    return () => {
      cancelled = true;
    };
  }, [worker?.id, player]);

  if (!source) return null;

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      <VideoView
        style={StyleSheet.absoluteFill}
        player={player}
        contentFit="cover"
        nativeControls={false}
        allowsPictureInPicture={false}
      />
    </View>
  );
}
