import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Svg, { Circle } from 'react-native-svg';

// Circular score ring — mirrors iOS VouchScoreRing.
export default function VouchScoreRing({ score = 0, size = 64, accent = '#ee6c4d' }) {
  const stroke = size * 0.09;
  const r = (size - stroke) / 2;
  const circ = 2 * Math.PI * r;
  const dash = (score / 100) * circ;

  return (
    <View style={{ width: size, height: size, alignItems: 'center', justifyContent: 'center' }}>
      <Svg width={size} height={size} style={StyleSheet.absoluteFill}>
        <Circle cx={size / 2} cy={size / 2} r={r}
          stroke="rgba(39,41,50,0.10)" strokeWidth={stroke} fill="none" />
        <Circle cx={size / 2} cy={size / 2} r={r}
          stroke={accent} strokeWidth={stroke} fill="none"
          strokeDasharray={`${dash} ${circ}`}
          strokeLinecap="round"
          rotation="-90" origin={`${size / 2},${size / 2}`} />
      </Svg>
      <Text style={{ fontSize: size * 0.25, fontWeight: '800', color: '#272932' }}>{score}</Text>
    </View>
  );
}
