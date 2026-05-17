import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

enum AppLanguage {
  english('en', 'English', 'EN'),
  hindi('hi', 'हिंदी', 'हि'),
  marathi('mr', 'मराठी', 'म'),
  telugu('te', 'తెలుగు', 'తె'),
  tamil('ta', 'தமிழ்', 'த'),
  kannada('kn', 'ಕನ್ನಡ', 'ಕ');

  const AppLanguage(this.code, this.displayName, this.shortCode);
  final String code;
  final String displayName;
  final String shortCode;

  static AppLanguage fromCode(String? code) =>
      AppLanguage.values.firstWhere((l) => l.code == code, orElse: () => AppLanguage.english);
}

class Swatch {
  const Swatch(this.name, this.hex);
  final String name;
  final String hex;
  Color get color => AppColors.fromHex(hex);

  static const all = [
    Swatch('Burnt Peach', '#ee6c4d'),
    Swatch('Coral Glow', '#f38d68'),
    Swatch('Crimson', '#E63946'),
    Swatch('Terracotta', '#C1440E'),
    Swatch('Amber', '#F4A261'),
    Swatch('Golden', '#E9B44C'),
    Swatch('Forest', '#2D6A4F'),
    Swatch('Sage', '#52796F'),
    Swatch('Ocean', '#118AB2'),
    Swatch('Navy', '#1D3557'),
    Swatch('Violet', '#7B2D8B'),
    Swatch('Magenta', '#C9184A'),
    Swatch('Teal', '#264653'),
    Swatch('Indigo', '#4361EE'),
    Swatch('Mint', '#06D6A0'),
    Swatch('Slate', '#4A5568'),
  ];
}

/// Mirrors iOS @Observable AppTheme.
class GrayManTheme extends ChangeNotifier {
  Color accent = Swatch.all.first.color;
  String accentHex = Swatch.all.first.hex;
  String swatchName = Swatch.all.first.name;
  AppLanguage language = AppLanguage.english;

  static const _langKey = 'app_language';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    language = AppLanguage.fromCode(prefs.getString(_langKey));
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang.code);
    notifyListeners();
  }

  void setSwatch(Swatch s) {
    accent = s.color;
    accentHex = s.hex;
    swatchName = s.name;
    notifyListeners();
  }

  String t(
    String en,
    String hi, {
    String? mr,
    String? te,
    String? ta,
    String? kn,
  }) {
    switch (language) {
      case AppLanguage.english:
        return en;
      case AppLanguage.hindi:
        return hi;
      case AppLanguage.marathi:
        return mr ?? en;
      case AppLanguage.telugu:
        return te ?? en;
      case AppLanguage.tamil:
        return ta ?? en;
      case AppLanguage.kannada:
        return kn ?? en;
    }
  }

  String get geminiLangCode => language.code;

  ThemeData get materialTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.canvas,
        colorScheme: ColorScheme.light(
          primary: accent,
          surface: AppColors.canvas,
          onSurface: AppColors.shadowGrey,
        ),
        fontFamily: 'Roboto',
      );
}
