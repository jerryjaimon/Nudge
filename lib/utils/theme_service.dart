import 'package:flutter/material.dart';
import '../storage.dart';

enum NudgeThemeMode {
  dark,
  brutal,
  neumorphic,
  cute,
  terminal,
}

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal() {
    _loadTheme();
  }

  NudgeThemeMode _mode = NudgeThemeMode.dark;
  NudgeThemeMode get mode => _mode;

  void _loadTheme() {
    final stored = AppStorage.settingsBox.get('theme_mode', defaultValue: 'dark') as String;
    _mode = NudgeThemeMode.values.firstWhere(
      (e) => e.name == stored,
      orElse: () => NudgeThemeMode.dark,
    );
  }

  Future<void> setTheme(NudgeThemeMode newMode) async {
    if (_mode == newMode) return;
    _mode = newMode;
    await AppStorage.settingsBox.put('theme_mode', newMode.name);
    notifyListeners();
  }

  bool get isBrutal => _mode == NudgeThemeMode.brutal;
  bool get isNeumorphic => _mode == NudgeThemeMode.neumorphic;
  bool get isCute => _mode == NudgeThemeMode.cute;
  bool get isTerminal => _mode == NudgeThemeMode.terminal;
  bool get isDark => _mode == NudgeThemeMode.dark;
}
