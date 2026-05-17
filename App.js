import React, { useState, useEffect, useCallback } from 'react';
import { StyleSheet, View, ActivityIndicator } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { AppThemeProvider } from './src/AppTheme';
import { tokenStore } from './src/api/tokenStore';
import { locationService } from './src/services/locationService';
import { Colors } from './src/theme';

import OnboardingScreen from './screens/OnboardingScreen';
import PhoneAuthScreen from './screens/PhoneAuthScreen';
import NameEntryScreen from './screens/NameEntryScreen';
import ChooseRoleScreen from './screens/ChooseRoleScreen';
import RecordReelScreen from './screens/RecordReelScreen';
import ExploreScreen from './screens/ExploreScreen';
import ProfileScreen from './screens/ProfileScreen';

/**
 * Routing mirrors iOS GrayManApp.swift flat state machine.
 */
export default function App() {
  return (
    <GestureHandlerRootView style={styles.root}>
      <SafeAreaProvider>
        <AppThemeProvider>
          <AppNavigator />
        </AppThemeProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

function AppNavigator() {
  const [booting, setBooting] = useState(true);
  const [screen, setScreen] = useState('onboarding');
  const [userName, setUserName] = useState('');
  const [selectedWorker, setSelectedWorker] = useState(null);
  const [previousScreen, setPreviousScreen] = useState('chooseRole');
  const [reelOrigin, setReelOrigin] = useState('chooseRole');
  const [isNewWorker, setIsNewWorker] = useState(true);

  useEffect(() => {
    (async () => {
      await tokenStore.load();
      await locationService.requestPermission();
      if (tokenStore.token) {
        setScreen('profile');
      }
      setBooting(false);
    })();
  }, []);

  const goExplore = useCallback(from => {
    setPreviousScreen(from);
    setScreen('explore');
  }, []);

  const handleSignOut = useCallback(async () => {
    await tokenStore.clear();
    setUserName('');
    setSelectedWorker(null);
    setPreviousScreen('chooseRole');
    setScreen('onboarding');
  }, []);

  if (booting) {
    return (
      <View style={styles.boot}>
        <ActivityIndicator size="large" color={Colors.shadowGrey} />
      </View>
    );
  }

  switch (screen) {
    case 'onboarding':
      return (
        <OnboardingScreen
          goNext={() => setScreen('phoneAuth')}
        />
      );

    case 'phoneAuth':
      return (
        <PhoneAuthScreen
          goBack={() => setScreen('onboarding')}
          goNext={({ isNew }) => {
            setIsNewWorker(isNew);
            setScreen(isNew ? 'nameEntry' : 'profile');
          }}
        />
      );

    case 'nameEntry':
      return (
        <NameEntryScreen
          goBack={() => setScreen('phoneAuth')}
          goNext={name => {
            setUserName(name);
            setScreen('chooseRole');
          }}
        />
      );

    case 'chooseRole':
      return (
        <ChooseRoleScreen
          name={(userName.split(' ')[0] || userName) || 'there'}
          goBack={() => setScreen('nameEntry')}
          goProfessional={() => {
            setReelOrigin('chooseRole');
            setScreen('recordReel');
          }}
          goExplore={() => goExplore('chooseRole')}
        />
      );

    case 'recordReel':
      return (
        <RecordReelScreen
          goBack={() => setScreen(reelOrigin)}
          goDone={() => setScreen('profile')}
        />
      );

    case 'explore':
      return (
        <ExploreScreen
          onBack={() => setScreen(previousScreen)}
          onViewProfile={worker => {
            setSelectedWorker(worker);
            setScreen('workerProfile');
          }}
          onGoProfile={() => setScreen('profile')}
        />
      );

    case 'workerProfile':
      return (
        <ProfileScreen
          worker={selectedWorker}
          onBack={() => setScreen('explore')}
        />
      );

    case 'profile':
      return (
        <ProfileScreen
          userName={userName}
          onExplore={() => goExplore('profile')}
          onSignOut={handleSignOut}
          onRecordReel={() => {
            setReelOrigin('profile');
            setScreen('recordReel');
          }}
        />
      );

    default:
      return null;
  }
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  boot: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.canvas,
  },
});
