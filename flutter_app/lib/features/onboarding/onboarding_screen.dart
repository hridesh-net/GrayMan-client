import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/blobs.dart';
import '../../core/design_system/press_scale.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Blobs(accent: theme.accent, opacity: 1),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(colors: [AppColors.shadowGrey, theme.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    boxShadow: [BoxShadow(color: theme.accent.withValues(alpha: 0.42), blurRadius: 14, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 28),
                Text('sthapna.ai', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: AppColors.shadowGrey, letterSpacing: -1.5)),
                const SizedBox(height: 8),
                Text(
                  theme.t('Digital identity for skilled workers', 'कुशल कामगारों की डिजिटल पहचान'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppColors.mutedText),
                ),
                const SizedBox(height: 6),
                Text('काम · सेतु', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.accent, letterSpacing: 0.6)),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  child: Column(
                    children: [
                      PressScaleButton(
                        onPressed: onNext,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: theme.accent.withValues(alpha: 0.36), blurRadius: 12, offset: const Offset(0, 6))]),
                          child: Text(theme.t('Get Started', 'शुरू करें'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      PressScaleButton(
                        onPressed: onNext,
                        scale: 0.98,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.shadowGrey.withValues(alpha: 0.18))),
                          child: Text(theme.t('Sign In', 'साइन इन'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.shadowGrey, fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(theme.t('By continuing you agree to our Terms & Privacy', 'जारी रखकर आप हमारी शर्तों और गोपनीयता से सहमत हैं'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.dimText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
