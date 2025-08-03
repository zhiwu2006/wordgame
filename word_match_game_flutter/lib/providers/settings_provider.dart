import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_match_game_flutter/services/settings_service.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _ttsEnabled = true;
  ThemeMode _themeMode = ThemeMode.system;

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get ttsEnabled => _ttsEnabled;
  ThemeMode get themeMode => _themeMode;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _soundEnabled = await _settingsService.isSoundEnabled();
    _vibrationEnabled = await _settingsService.isVibrationEnabled();
    _ttsEnabled = await _settingsService.isTtsEnabled();
    
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];
    
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    await _settingsService.setSoundEnabled(value);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    await _settingsService.setVibrationEnabled(value);
    notifyListeners();
  }

  Future<void> setTtsEnabled(bool value) async {
    _ttsEnabled = value;
    await _settingsService.setTtsEnabled(value);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }
}