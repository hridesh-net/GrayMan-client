import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/blobs.dart';
import '../../core/design_system/press_scale.dart';
import '../../core/networking/token_store.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onSignOut, required this.onBack});
  final VoidCallback onSignOut;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Blobs(accent: theme.accent, opacity: 0.5),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
                    Text(theme.t('Settings', 'सेटिंग'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 24),
                Text(theme.t('Language', 'भाषा'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...AppLanguage.values.map((l) => RadioListTile<AppLanguage>(
                      title: Text(l.displayName),
                      value: l,
                      groupValue: theme.language,
                      onChanged: (v) { if (v != null) theme.setLanguage(v); },
                    )),
                const SizedBox(height: 24),
                Text(theme.t('Accent colour', 'रंग'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: Swatch.all.map((s) => GestureDetector(
                        onTap: () => theme.setSwatch(s),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: s.color, shape: BoxShape.circle, border: theme.swatchName == s.name ? Border.all(color: AppColors.shadowGrey, width: 2) : null),
                        ),
                      )).toList(),
                ),
                const SizedBox(height: 40),
                PressScaleButton(
                  onPressed: () async {
                    await TokenStore.instance.clear();
                    onSignOut();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border.all(color: AppColors.errorRed), borderRadius: BorderRadius.circular(14)),
                    child: Text(theme.t('Sign Out', 'साइन आउट'), style: const TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
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
