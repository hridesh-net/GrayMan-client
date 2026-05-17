import 'package:flutter/material.dart';

/// Brand palette — mirrors DesignSystem.swift + Theme.swift.
class AppColors {
  static const shadowGrey = Color(0xFF272932);
  static const burntPeach = Color(0xFFEE6C4D);
  static const coralGlow = Color(0xFFF38D68);
  static const canvas = Color(0xFFFAFAF9);
  static const soft = Color(0xFFF2F0EF);
  static const mutedText = Color(0xFF6B6E7A);
  static const dimText = Color(0xFF9DA1AD);
  static const verifiedBlue = Color(0xFF1DA1F2);
  static const errorRed = Color(0xFFE63946);

  static Color fromHex(String hex) {
    final s = hex.startsWith('#') ? hex.substring(1) : hex;
    final v = int.parse(s, radix: 16);
    return Color(0xFF000000 | v);
  }
}
