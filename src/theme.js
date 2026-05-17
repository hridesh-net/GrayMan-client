export const Colors = {
  canvas:       '#F5F4F0',
  shadowGrey:   '#272932',
  soft:         '#EEECEA',
  mutedText:    '#6B7280',
  dimText:      '#9DA1AD',
  verifiedBlue: '#3B82F6',
  white:        '#FFFFFF',
  recordRed:    '#E63946',
};

export const Swatches = [
  { name: 'Burnt Peach', hex: '#ee6c4d' },
  { name: 'Coral Glow',  hex: '#f38d68' },
  { name: 'Crimson',     hex: '#E63946' },
  { name: 'Terracotta',  hex: '#C1440E' },
  { name: 'Amber',       hex: '#F4A261' },
  { name: 'Golden',      hex: '#E9B44C' },
  { name: 'Forest',      hex: '#2D6A4F' },
  { name: 'Sage',        hex: '#52796F' },
  { name: 'Ocean',       hex: '#118AB2' },
  { name: 'Navy',        hex: '#1D3557' },
  { name: 'Violet',      hex: '#7B2D8B' },
  { name: 'Magenta',     hex: '#C9184A' },
  { name: 'Teal',        hex: '#264653' },
  { name: 'Indigo',      hex: '#4361EE' },
  { name: 'Mint',        hex: '#06D6A0' },
  { name: 'Slate',       hex: '#4A5568' },
];

export const Spacing = { xs: 4, sm: 8, md: 16, lg: 24, xl: 32 };

export const Radius = { sm: 8, md: 12, lg: 16, xl: 20, full: 999 };

export const Shadow = {
  card: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.08,
    shadowRadius: 12,
    elevation: 4,
  },
  button: {
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.30,
    shadowRadius: 10,
    elevation: 6,
  },
};

export const hexToRgba = (hex, a) => {
  if (!hex) return `rgba(0,0,0,${a})`;
  let cleanHex = hex.replace('#', '');
  if (cleanHex.length === 3) cleanHex = cleanHex.split('').map(c => c + c).join('');
  const r = parseInt(cleanHex.slice(0, 2), 16);
  const g = parseInt(cleanHex.slice(2, 4), 16);
  const b = parseInt(cleanHex.slice(4, 6), 16);
  return `rgba(${r},${g},${b},${a})`;
};

export const Glass = {
  // Matches iOS .glassEffect(.regular) — white frosted card
  regular: {
    intensity: 60,
    tint: 'light',
    backgroundColor: 'rgba(255,255,255,0.82)',
    borderColor: 'rgba(255,255,255,0.92)',
    borderWidth: 1,
  },
  // Common for profile cards, etc.
  light: {
    backgroundColor: 'rgba(255,255,255,0.88)',
    borderColor: 'rgba(255,255,255,0.95)',
    borderWidth: 1,
  },
  dark: {
    backgroundColor: 'rgba(0,0,0,0.07)',
    borderColor: 'rgba(0,0,0,0.10)',
    borderWidth: 1,
  },
  deep: {
    backgroundColor: 'rgba(255,255,255,0.12)',
    borderColor: 'rgba(255,255,255,0.20)',
    borderWidth: 1,
  }
};

