/// Theme provider — persists theme mode to Hive and provides reactive state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../data/settings_data.dart';

/// Supported theme modes for the app.
enum AppThemeMode {
  /// Follow system setting.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// Extension to convert [AppThemeMode] to Flutter's [ThemeMode].
extension AppThemeModeExtension on AppThemeMode {
  ThemeMode get flutterThemeMode => switch (this) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };
}

/// Notifier that manages theme mode persistence and state.
class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    final box = Hive.box(kSettingsBoxName);
    final stored = box.get(SettingsKeys.themeMode, defaultValue: 'system');
    return AppThemeMode.values.firstWhere(
      (e) => e.name == stored,
      orElse: () => AppThemeMode.system,
    );
  }

  /// Set the theme mode and persist to Hive.
  void setMode(AppThemeMode mode) {
    Hive.box(kSettingsBoxName).put(SettingsKeys.themeMode, mode.name);
    state = mode;
  }
}

/// Provider for the current theme mode.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);
