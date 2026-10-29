import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemeModeKey = 'nas_dash_theme_mode';
const String _kUseDynamicColorsKey = 'nas_dash_use_dynamic_colors';

class ThemeSettings {
  final ThemeMode themeMode;
  final bool useDynamicColors;

  const ThemeSettings({
    this.themeMode = ThemeMode.system,
    this.useDynamicColors = true,
  });

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    bool? useDynamicColors,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      useDynamicColors: useDynamicColors ?? this.useDynamicColors,
    );
  }
}

final themeSettingsProvider =
    StateNotifierProvider<ThemeSettingsNotifier, ThemeSettings>((ref) {
  return ThemeSettingsNotifier();
});

class ThemeSettingsNotifier extends StateNotifier<ThemeSettings> {
  ThemeSettingsNotifier() : super(const ThemeSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt(_kThemeModeKey) ?? ThemeMode.system.index;
      final useDynamic = prefs.getBool(_kUseDynamicColorsKey) ?? true;

      state = ThemeSettings(
        themeMode: ThemeMode.values[modeIndex.clamp(0, ThemeMode.values.length - 1)],
        useDynamicColors: useDynamic,
      );
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeModeKey, mode.index);
  }

  Future<void> setUseDynamicColors(bool useDynamic) async {
    state = state.copyWith(useDynamicColors: useDynamic);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseDynamicColorsKey, useDynamic);
  }
}
