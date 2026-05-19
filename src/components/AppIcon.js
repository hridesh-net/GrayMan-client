import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

/** Ionicons names aligned with iOS SF Symbols used in GrayMan.swiftpm. */
export const Icons = {
  home: 'home',
  explore: 'grid',
  profile: 'person-circle',
  settings: 'settings',
  heart: 'heart-outline',
  heartFill: 'heart',
  bookmark: 'bookmark-outline',
  bookmarkFill: 'bookmark',
  chat: 'chatbubble',
  share: 'open-outline',
  vouch: 'shield-outline',
  vouchFill: 'shield-checkmark',
  location: 'location',
  search: 'search',
  menu: 'menu',
  close: 'close',
  bolt: 'flash',
  camera: 'camera',
  film: 'film',
  mic: 'mic',
  star: 'star-outline',
  starFill: 'star',
  checkmark: 'checkmark',
  checkmarkSeal: 'checkmark-circle',
  bell: 'notifications',
  plus: 'add',
  arrowRight: 'arrow-forward',
  person: 'person',
  notifications: 'notifications-outline',
  whatsapp: 'logo-whatsapp',
  hire: 'flash',
  proof: 'film',
  interview: 'mic',
};

export function tradeIconName(trade = '') {
  const lower = trade.toLowerCase();
  if (lower.includes('electric')) return 'flash';
  if (lower.includes('plumb')) return 'water';
  if (lower.includes('hvac') || lower.includes('ac ')) return 'snow';
  if (lower.includes('interior') || lower.includes('decorator')) return 'color-palette';
  if (lower.includes('weld')) return 'flame';
  if (lower.includes('nurse')) return 'medkit';
  if (lower.includes('carpenter')) return 'hammer';
  if (lower.includes('paint')) return 'color-palette';
  if (lower.includes('mason')) return 'cube';
  if (lower.includes('cook')) return 'restaurant';
  if (lower.includes('driver')) return 'car';
  if (lower.includes('guard') || lower.includes('security')) return 'shield';
  if (lower.includes('tailor')) return 'shirt';
  if (lower.includes('garden')) return 'leaf';
  if (lower.includes('appliance') || lower.includes('repair')) return 'build';
  if (lower.includes('mechanic')) return 'cog';
  return 'construct';
}

export default function AppIcon({ name, size = 22, color = '#000', style }) {
  return <Ionicons name={name} size={size} color={color} style={style} />;
}

/** Large trade avatar fallback (Explore reel background). */
export function TradeIcon({ trade, size = 54, color = '#fff', style }) {
  return (
    <AppIcon
      name={tradeIconName(trade)}
      size={size}
      color={color}
      style={style}
    />
  );
}

/** Icon + label row for buttons (replaces emoji prefixes in text). */
export function IconLabel({
  icon,
  size = 18,
  color,
  children,
  style,
  textStyle,
  gap = 8,
}) {
  return (
    <View style={[styles.iconLabel, { gap }, style]}>
      <AppIcon name={icon} size={size} color={color} />
      {typeof children === 'string' ? (
        <Text style={textStyle}>{children}</Text>
      ) : (
        children
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  iconLabel: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
});
