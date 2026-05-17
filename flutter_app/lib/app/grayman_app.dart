import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/design_system/app_colors.dart';
import '../core/networking/token_store.dart';
import '../models/worker.dart';
import 'screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/auth/phone_auth_screen.dart';
import '../features/onboarding/name_entry_screen.dart';
import '../features/onboarding/avatar_picker_screen.dart';
import '../features/onboarding/choose_role_screen.dart';
import '../features/reel/record_reel_screen.dart';
import '../features/explore/reel_feed_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';

/// Composition root — mirrors GrayManApp.swift flat state machine.
class GrayManApp extends StatefulWidget {
  const GrayManApp({super.key});

  @override
  State<GrayManApp> createState() => _GrayManAppState();
}

class _GrayManAppState extends State<GrayManApp> {
  late AppScreen _screen;
  bool _booting = true;
  String _userName = '';
  Worker? _selectedWorker;
  AppScreen _previousScreen = AppScreen.chooseRole;
  AppScreen _reelOrigin = AppScreen.chooseRole;

  @override
  void initState() {
    super.initState();
    _screen = TokenStore.instance.token != null ? AppScreen.home : AppScreen.onboarding;
    Future.microtask(() => setState(() => _booting = false));
  }

  void _goExplore(AppScreen from) {
    setState(() {
      _previousScreen = from;
      _screen = AppScreen.explore;
    });
  }

  void _signOut() async {
    await TokenStore.instance.clear();
    setState(() {
      _userName = '';
      _selectedWorker = null;
      _previousScreen = AppScreen.chooseRole;
      _screen = AppScreen.onboarding;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(child: CircularProgressIndicator(color: AppColors.shadowGrey)),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(key: ValueKey(_screen), child: _buildScreen()),
    );
  }

  Widget _buildScreen() {
    switch (_screen) {
      case AppScreen.onboarding:
        return OnboardingScreen(onNext: () => setState(() => _screen = AppScreen.phoneAuth));

      case AppScreen.phoneAuth:
        return PhoneAuthScreen(
          onBack: () => setState(() => _screen = AppScreen.onboarding),
          onNext: () => setState(() => _screen = AppScreen.nameEntry),
        );

      case AppScreen.nameEntry:
        return NameEntryScreen(
          onBack: () => setState(() => _screen = AppScreen.phoneAuth),
          onNext: (name) {
            setState(() {
              _userName = name;
              _screen = AppScreen.avatarOnboarding;
            });
          },
        );

      case AppScreen.avatarOnboarding:
        return AvatarPickerScreen(
          name: _userName,
          onBack: () => setState(() => _screen = AppScreen.nameEntry),
          onNext: () => setState(() => _screen = AppScreen.chooseRole),
        );

      case AppScreen.chooseRole:
        final first = _userName.split(' ').firstOrNull ?? _userName;
        return ChooseRoleScreen(
          name: first.isEmpty ? 'there' : first,
          onBack: () => setState(() => _screen = AppScreen.avatarOnboarding),
          onProfessional: () => setState(() {
            _reelOrigin = AppScreen.chooseRole;
            _screen = AppScreen.recordReel;
          }),
          onExplore: () => _goExplore(AppScreen.chooseRole),
        );

      case AppScreen.recordReel:
        return RecordReelScreen(
          onBack: () => setState(() => _screen = _reelOrigin),
          onDone: (_) => setState(() => _screen = AppScreen.home),
        );

      case AppScreen.explore:
        return ReelFeedScreen(
          onBack: () => setState(() => _screen = _previousScreen),
          onViewProfile: (w) => setState(() {
            _selectedWorker = w;
            _screen = AppScreen.workerProfile;
          }),
          onGoProfile: () => setState(() => _screen = AppScreen.profile),
          onGoHome: () => setState(() => _screen = AppScreen.home),
          onGoSettings: () => setState(() => _screen = AppScreen.profile),
        );

      case AppScreen.workerProfile:
        return ProfileScreen(
          worker: _selectedWorker,
          onBack: () => setState(() => _screen = AppScreen.explore),
        );

      case AppScreen.home:
        return HomeScreen(
          userName: _userName,
          onProfile: () => setState(() => _screen = AppScreen.profile),
          onExplore: () => _goExplore(AppScreen.home),
          onSettings: () => setState(() => _screen = AppScreen.profile),
          onViewWorker: (w) => setState(() {
            _selectedWorker = w;
            _screen = AppScreen.workerProfile;
          }),
        );

      case AppScreen.profile:
        return ProfileScreen(
          userName: _userName,
          onExplore: () => _goExplore(AppScreen.profile),
          onSignOut: _signOut,
          onRecordReel: () => setState(() {
            _reelOrigin = AppScreen.profile;
            _screen = AppScreen.recordReel;
          }),
          onHome: () => setState(() => _screen = AppScreen.home),
        );
    }
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
