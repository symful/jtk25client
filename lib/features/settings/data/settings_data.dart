/// Settings data layer — Hive-backed persistence for user preferences.
library;

/// Hive box name for app settings.
const String kSettingsBoxName = 'jtk_settings';

/// Keys for the settings box.
class SettingsKeys {
  SettingsKeys._();

  /// The currently selected class code (e.g. "D3-3A").
  static const String selectedClass = 'selected_class';
}

/// All known class codes in the app.
const List<String> kAllClassCodes = [
  'D3-3A',
  'D3-3B',
  'D4-3T-A',
  'D4-3T-B',
  'D4-3T-C',
  'D4-3T-D',
];

/// Human-readable label for a class code.
String classLabel(String code) => code;
