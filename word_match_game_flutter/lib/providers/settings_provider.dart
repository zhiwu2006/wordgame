import 'package:flutter/material.dart';
import 'package:word_match_game_flutter/services/settings_service.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _ttsEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get ttsEnabled => _ttsEnabled;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _soundEnabled = await _settingsService.isSoundEnabled();
    _vibrationEnabled = await _settingsService.isVibrationEnabled();
    _ttsEnabled = await _settingsService.isTtsEnabled();
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
}
