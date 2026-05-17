import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/blobs.dart';
import '../../core/design_system/press_scale.dart';

class ChooseRoleScreen extends StatelessWidget {
  const ChooseRoleScreen({
    super.key,
    required this.name,
    required this.onBack,
    required this.onProfessional,
    required this.onExplore,
  });

  final String name;
  final VoidCallback onBack;
  final VoidCallback onProfessional;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Blobs(accent: theme.accent, opacity: 0.8),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                  child: IconButton(
                    onPressed: onBack,
                    style: IconButton.styleFrom(backgroundColor: AppColors.soft),
                    icon: const Icon(Icons.arrow_back, size: 20),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(theme.t('WELCOME ABOARD', 'स्वागत है'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: theme.accent, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      Text(theme.t('Hey $name 👋\nWhat brings\nyou here?', 'नमस्ते $name 👋\nआप यहाँ\nकिसलिए आए?'), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.shadowGrey, height: 1.15, letterSpacing: -1.4)),
                      const SizedBox(height: 8),
                      Text(theme.t("Choose how you'd like to use sthapna.ai", 'sthapna.ai का उपयोग कैसे करना चाहते हैं?'), style: const TextStyle(fontSize: 15, color: AppColors.mutedText)),
                      const SizedBox(height: 24),
                      _RoleCard(
                        accent: theme.accent,
                        icon: Icons.build,
                        title: theme.t("I'm a Professional", 'मैं प्रोफ़ेशनल हूं'),
                        subtitle: theme.t('Create your verified work profile. Electricians, plumbers, mechanics & 50+ trades.', 'अपनी सत्यापित वर्क प्रोफ़ाइल बनाएं।'),
                        onTap: onProfessional,
                      ),
                      const SizedBox(height: 16),
                      _RoleCard(
                        accent: theme.accent,
                        icon: Icons.explore,
                        title: theme.t('Explore Workers', 'कामगार खोजें'),
                        subtitle: theme.t('Find skilled workers near you by trade and radius.', 'पास के कुशल कामगार खोजें।'),
                        onTap: onExplore,
                        outlined: true,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.accent, required this.icon, required this.title, required this.subtitle, required this.onTap, this.outlined = false});
  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return PressScaleButton(
      onPressed: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: outlined ? Colors.white : AppColors.soft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: outlined ? AppColors.shadowGrey.withValues(alpha: 0.12) : Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [AppColors.shadowGrey, accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.shadowGrey)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.mutedText)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: AppColors.dimText),
          ],
        ),
      ),
    );
  }
}
