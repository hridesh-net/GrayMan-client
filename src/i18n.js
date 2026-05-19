import { STRINGS } from './i18n/translations';

export const AppLanguages = [
  { key: 'en', displayName: 'English', shortCode: 'EN' },
  { key: 'hi', displayName: 'हिंदी',   shortCode: 'हि' },
  { key: 'mr', displayName: 'मराठी',   shortCode: 'म'  },
  { key: 'te', displayName: 'తెలుగు',  shortCode: 'తె' },
  { key: 'ta', displayName: 'தமிழ்',   shortCode: 'த'  },
  { key: 'kn', displayName: 'ಕನ್ನಡ',   shortCode: 'ಕ'  },
];

const LANG_KEYS = ['en', 'hi', 'mr', 'te', 'ta', 'kn'];

function pickLang(entry, language) {
  if (!entry) return '';
  if (entry[language]) return entry[language];
  // Regional Indian languages: prefer Hindi over English when missing
  if (language !== 'en' && language !== 'hi' && entry.hi) return entry.hi;
  return entry.en ?? '';
}

/**
 * Bilingual/regional translator used across the app.
 *
 * - t('English key', 'हिंदी') — looks up catalog by English key when available
 * - t('English', 'हिंदी', { mr, te, ta, kn }) — inline overrides
 * - t({ en, hi, mr, te, ta, kn }) — object form
 */
export function makeT(language) {
  return function t(en, hiOrOpts, maybeOpts) {
    let opts = {};
    let hi = hiOrOpts;

    if (typeof en === 'object' && en !== null) {
      return pickLang(en, language);
    }

    if (typeof hiOrOpts === 'object' && hiOrOpts !== null && !Array.isArray(hiOrOpts)) {
      opts = hiOrOpts;
      hi = opts.hi ?? en;
    } else if (typeof maybeOpts === 'object' && maybeOpts) {
      opts = maybeOpts;
    }

    const catalog = STRINGS[en];
    if (catalog) {
      return pickLang({ ...catalog, ...opts }, language);
    }

    return pickLang({ en, hi: hi ?? en, ...opts }, language);
  };
}

/** "Day 3" with correct word order for all languages. */
export function dayLabel(t, n) {
  return `${t('Day', 'दिन')} ${n}`;
}

/** Interpolate {name} placeholders in a translated template. */
export function tpl(t, en, hi, vars = {}, extra = {}) {
  const raw = t(en, hi, extra);
  return raw.replace(/\{(\w+)\}/g, (_, key) => (vars[key] != null ? String(vars[key]) : `{${key}}`));
}

export { STRINGS };
