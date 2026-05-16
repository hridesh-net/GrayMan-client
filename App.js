import React, { useState } from 'react';
import { StyleSheet } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { AppThemeProvider } from './src/AppTheme';

import OnboardingScreen  from './screens/OnboardingScreen';
import PhoneAuthScreen   from './screens/PhoneAuthScreen';
import NameEntryScreen   from './screens/NameEntryScreen';
import ChooseRoleScreen  from './screens/ChooseRoleScreen';
import RecordReelScreen  from './screens/RecordReelScreen';
import ExploreScreen     from './screens/ExploreScreen';
import ProfileScreen     from './screens/ProfileScreen';

// Routing mirrors iOS GrayManApp.swift flat state machine.
//
// onboarding → nameEntry → chooseRole
//                              ├── recordReel → profile
//                              └── explore ⇄ workerProfile
//                                     └── profile
//
// Phone auth exists but routing currently bypasses it (same as iOS).

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
  const [screen, setScreen]                 = useState('onboarding');
  const [userName, setUserName]             = useState('');
  const [selectedWorker, setSelectedWorker] = useState(null);
  const [previousScreen, setPreviousScreen] = useState('chooseRole');

  const goExplore = (from) => {
    setPreviousScreen(from);
    setScreen('explore');
  };

  switch (screen) {
    case 'onboarding':
      return <OnboardingScreen goNext={() => setScreen('nameEntry')} />;

    case 'phoneAuth':
      return (
        <PhoneAuthScreen
          goBack={() => setScreen('onboarding')}
          goNext={() => setScreen('nameEntry')}
        />
      );

    case 'nameEntry':
      return (
        <NameEntryScreen
          goBack={() => setScreen('onboarding')}
          goNext={(name) => { setUserName(name); setScreen('chooseRole'); }}
        />
      );

    case 'chooseRole':
      return (
        <ChooseRoleScreen
          name={userName.split(' ')[0] || userName}
          goBack={() => setScreen('nameEntry')}
          goProfessional={() => setScreen('recordReel')}
          goExplore={() => goExplore('chooseRole')}
        />
      );

    case 'recordReel':
      return (
        <RecordReelScreen
          goBack={() => setScreen('chooseRole')}
          goDone={() => setScreen('profile')}
        />
      );

    case 'explore':
      return (
        <ExploreScreen
          onBack={() => setScreen(previousScreen)}
          onViewProfile={(worker) => { setSelectedWorker(worker); setScreen('workerProfile'); }}
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
          userName={userName || 'Ramesh Kumar'}
          onExplore={() => goExplore('profile')}
        />
      );

    default:
      return null;
  }
}

const styles = StyleSheet.create({ root: { flex: 1 } });
