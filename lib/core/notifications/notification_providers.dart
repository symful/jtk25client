/// Riverpod providers for notification state management.
///
/// Uses Notifier + NotifierProvider pattern (Riverpod 3.x).
/// Persisted notification preference in Hive settings box.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../notifications/fcm_service.dart';
import '../notifications/notification_service.dart';
import '../../features/settings/data/settings_data.dart';

// ---------------------------------------------------------------------------
// Notification enabled toggle (Hive-persisted)
// ---------------------------------------------------------------------------

/// Hive key for the notification enabled preference.
const String _kNotificationsEnabledKey = 'notifications_enabled';

class _NotificationEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final box = Hive.box(kSettingsBoxName);
    return box.get(_kNotificationsEnabledKey) as bool? ?? false;
  }

  /// Toggle notifications on/off and persist the choice.
  void toggle(bool value) {
    state = value;
    Hive.box(kSettingsBoxName).put(_kNotificationsEnabledKey, value);

    final service = NotificationService.instance;
    if (value) {
      service.requestPermission().then((granted) {
        if (granted) {
          service.startPolling();
        } else {
          // Permission denied — turn off the toggle.
          state = false;
          Hive.box(kSettingsBoxName).put(_kNotificationsEnabledKey, false);
        }
      });
    } else {
      service.stopPolling();
    }
  }
}

/// Whether notifications are enabled (persisted in Hive).
final notificationEnabledProvider =
    NotifierProvider<_NotificationEnabledNotifier, bool>(
      _NotificationEnabledNotifier.new,
    );

// ---------------------------------------------------------------------------
// Notification status text (async — checks platform permission state)
// ---------------------------------------------------------------------------

/// Human-readable notification status in Indonesian.
///
/// Returns one of:
/// - "Aktif" — notifications enabled and permission granted
/// - "Nonaktif" — notifications disabled by user
/// - "Nonaktif (izin ditolak)" — notifications enabled but permission denied
final notificationStatusProvider = FutureProvider<String>((ref) async {
  final enabled = ref.watch(notificationEnabledProvider);
  if (!enabled) return 'Nonaktif';

  final service = NotificationService.instance;
  final isEnabled = await service.isEnabled();
  return isEnabled ? 'Aktif' : 'Nonaktif (izin ditolak)';
});

// ---------------------------------------------------------------------------
// Notification service provider (singleton)
// ---------------------------------------------------------------------------

/// Provider exposing the [NotificationService] singleton.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

// ---------------------------------------------------------------------------
// FCM push status
// ---------------------------------------------------------------------------

/// Human-readable FCM push status in Bahasa Indonesia.
final fcmStatusProvider = FutureProvider<String>((ref) async {
  return FcmService.instance.pushStatusText();
});

/// Provider exposing the [FcmService] singleton.
final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService.instance;
});
