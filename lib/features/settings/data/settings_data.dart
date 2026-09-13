/// Settings data layer — Hive-backed persistence for user preferences.
library;

/// Hive box name for app settings.
const String kSettingsBoxName = 'jtk_settings';

/// Keys for the settings box.
class SettingsKeys {
  SettingsKeys._();

  /// The currently selected class code (e.g. "D3-2A").
  static const String selectedClass = 'selected_class';

  /// Whether notifications are enabled.
  static const String notificationsEnabled = 'notifications_enabled';

  /// Last-seen data version (for notification dedup).
  static const String lastDataVersion = 'notification_last_data_version';
}

/// All known class codes in the app.
const List<String> kAllClassCodes = [
  'D3-2A',
  'D3-2B',
  'D4-2A',
  'D4-2B',
  'D4-2C',
  'D4-2D',
];

/// Human-readable label for a class code.
String classLabel(String code) => code;
