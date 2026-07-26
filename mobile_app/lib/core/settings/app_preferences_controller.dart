import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesController extends ChangeNotifier {
  AppPreferencesController._();

  static final AppPreferencesController instance = AppPreferencesController._();

  static const String _languageKey = 'mindpulse_language_code';
  static const String _themeKey = 'mindpulse_theme_mode';

  String _languageCode = 'en';
  String _themeMode = 'system';

  String get languageCode => _languageCode;
  String get themeModeCode => _themeMode;
  bool get isBangla => _languageCode == 'bn';

  Locale get locale => Locale(_languageCode);

  ThemeMode get themeMode {
    switch (_themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _languageCode = _normalizeLanguage(preferences.getString(_languageKey));
    _themeMode = _normalizeTheme(preferences.getString(_themeKey));
  }

  Future<void> apply({
    String? languageCode,
    String? themeMode,
    bool persist = true,
  }) async {
    final nextLanguage = languageCode == null
        ? _languageCode
        : _normalizeLanguage(languageCode);
    final nextTheme = themeMode == null
        ? _themeMode
        : _normalizeTheme(themeMode);

    final changed = nextLanguage != _languageCode || nextTheme != _themeMode;

    _languageCode = nextLanguage;
    _themeMode = nextTheme;

    if (persist) {
      final preferences = await SharedPreferences.getInstance();
      await Future.wait<bool>([
        preferences.setString(_languageKey, _languageCode),
        preferences.setString(_themeKey, _themeMode),
      ]);
    }

    if (changed) {
      notifyListeners();
    }
  }

  String text(String english, String bangla) {
    return isBangla ? bangla : english;
  }

  String _normalizeLanguage(String? value) {
    return value == 'bn' ? 'bn' : 'en';
  }

  String _normalizeTheme(String? value) {
    return const <String>{'system', 'light', 'dark'}.contains(value)
        ? value!
        : 'system';
  }
}
