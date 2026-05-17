import 'package:flutter/material.dart';
import 'glass_card.dart';
import 'app_colors.dart';

enum TabItem { home, explore, profile, settings }

/// Mirrors FloatingTabBar.swift — glass tab bar with center + action.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.active,
    required this.accent,
    required this.onHome,
    required this.onExplore,
    required this.onProfile,
    required this.onSettings,
    this.onCenterAction,
    this.t,
  });

  final TabItem active;
  final Color accent;
  final VoidCallback onHome;
  final VoidCallback onExplore;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback? onCenterAction;
  final String Function(String en, String hi)? t;

  String _t(String en, String hi) => t?.call(en, hi) ?? en;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      borderRadius: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _tab(Icons.home_rounded, _t('Home', 'होम'), TabItem.home, onHome),
          _tab(Icons.explore_rounded, _t('Explore', 'खोजें'), TabItem.explore, onExplore),
          if (onCenterAction != null)
            GestureDetector(
              onTap: onCenterAction,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          _tab(Icons.person_rounded, _t('Profile', 'प्रोफ़ाइल'), TabItem.profile, onProfile),
          _tab(Icons.settings_rounded, _t('Settings', 'सेटिंग'), TabItem.settings, onSettings),
        ],
      ),
    );
  }

  Widget _tab(IconData icon, String label, TabItem item, VoidCallback onTap) {
    final selected = active == item;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: selected ? accent : AppColors.dimText),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? accent : AppColors.dimText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
