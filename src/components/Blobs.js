import React from 'react';
import { View, StyleSheet } from 'react-native';

// Decorative background blobs — mirrors iOS Blobs view.
export default function Blobs({ accent = '#ee6c4d', opacity = 0.5 }) {
  const alpha = Math.round(opacity * 255).toString(16).padStart(2, '0');
  const color = accent + alpha;
  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      <View style={[styles.blob, styles.blob1, { backgroundColor: color }]} />
      <View style={[styles.blob, styles.blob2, { backgroundColor: color }]} />
      <View style={[styles.blob, styles.blob3, { backgroundColor: color }]} />
    </View>
  );
}

const styles = StyleSheet.create({
  blob: { position: 'absolute', borderRadius: 999 },
  blob1: { width: 320, height: 320, top: -80,  right: -80  },
  blob2: { width: 240, height: 240, bottom: 60, left: -60   },
  blob3: { width: 160, height: 160, top: '45%', right: -40  },
});
