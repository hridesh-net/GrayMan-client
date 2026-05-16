import React, { useRef } from 'react';
import { Animated, Pressable } from 'react-native';

// Mirrors iOS PressScaleStyle — scales down on press, springs back on release.
export default function PressScale({ onPress, scale = 0.96, style, children, disabled = false }) {
  const anim = useRef(new Animated.Value(1)).current;

  const onPressIn = () => {
    Animated.spring(anim, { toValue: scale, useNativeDriver: true, speed: 40, bounciness: 0 }).start();
  };

  const onPressOut = () => {
    Animated.spring(anim, { toValue: 1, useNativeDriver: true, speed: 20, bounciness: 4 }).start();
  };

  return (
    <Pressable onPress={onPress} onPressIn={onPressIn} onPressOut={onPressOut} disabled={disabled}>
      <Animated.View style={[style, { transform: [{ scale: anim }] }]}>
        {children}
      </Animated.View>
    </Pressable>
  );
}
