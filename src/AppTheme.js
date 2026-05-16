import React, { createContext, useContext, useState, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Swatches, Colors } from './theme';
import { makeT } from './i18n';

const AppThemeContext = createContext(null);

export function AppThemeProvider({ children }) {
  const [accent, setAccent]       = useState(Swatches[0].hex);
  const [swatchName, setSwatchName] = useState(Swatches[0].name);
  const [language, setLang]       = useState('en');

  useEffect(() => {
    AsyncStorage.getItem('app_language').then(val => {
      if (val) setLang(val);
    });
  }, []);

  const setLanguage = async (lang) => {
    setLang(lang);
    await AsyncStorage.setItem('app_language', lang);
  };

  const setSwatch = (swatch) => {
    setAccent(swatch.hex);
    setSwatchName(swatch.name);
  };

  const t = makeT(language);

  return (
    <AppThemeContext.Provider value={{ accent, swatchName, language, setLanguage, setSwatch, t, Colors }}>
      {children}
    </AppThemeContext.Provider>
  );
}

export function useTheme() {
  const ctx = useContext(AppThemeContext);
  if (!ctx) throw new Error('useTheme must be used inside AppThemeProvider');
  return ctx;
}
