export const AppLanguages = [
  { key: 'en', displayName: 'English', shortCode: 'EN' },
  { key: 'hi', displayName: 'हिंदी',   shortCode: 'हि' },
  { key: 'mr', displayName: 'मराठी',   shortCode: 'म'  },
  { key: 'te', displayName: 'తెలుగు',  shortCode: 'తె' },
  { key: 'ta', displayName: 'தமிழ்',   shortCode: 'த'  },
  { key: 'kn', displayName: 'ಕನ್ನಡ',   shortCode: 'ಕ'  },
];

// Mirrors iOS theme.t() — existing 2-arg calls work, extra langs optional.
export function makeT(language) {
  return function t(en, hi, opts = {}) {
    const { mr, te, ta, kn } = opts;
    switch (language) {
      case 'hi': return hi;
      case 'mr': return mr ?? en;
      case 'te': return te ?? en;
      case 'ta': return ta ?? en;
      case 'kn': return kn ?? en;
      default:   return en;
    }
  };
}
