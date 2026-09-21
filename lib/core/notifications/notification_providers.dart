/// Riverpod providers for notification state management.
///
/// Uses Notifier + NotifierProvider pattern (Riverpod 3.x).
/// Persisted notification preference in Hive settings box.
///
/// Auto topic re-subscribe: when the selected class changes and
/// notifications are enabled, FCM topics are updated silently via
/// ref.listen inside the notification enabled notifier.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../utils/debug_log.dart';
import '../notifications/fcm_service.dart';
import '../notifications/notification_service.dart';
import '../../features/settings/data/settings_data.dart';
import '../../features/schedule/providers/schedule_providers.dart';

// ---------------------------------------------------------------------------
// Notification enabled toggle (Hive-persisted)
// ---------------------------------------------------------------------------

/// Hive key for the notification enabled preference.
const String _kNotificationsEnabledKey = 'notifications_enabled';

/// Callback type for rescheduling reminders after toggle.
typedef RescheduleCallback = Future<void> Function();

class _NotificationEnabledNotifier extends Notifier<bool> {
  RescheduleCallback? _onReschedule;

  @override
  bool build() {
    final box = Hive.box(kSettingsBoxName);
    final enabled = box.get(_kNotificationsEnabledKey) as bool? ?? false;

    // Auto re-subscribe FCM topic when the selected class changes.
    // ref.listen fires the callback on every change — silent, no UI jargon.
    ref.listen<String>(selectedClassProvider, (previous, next) {
      if (state && next.isNotEmpty) {
        debugLog('[FCM] selectedClass changed: $previous → $next');
        FcmService.instance.subscribeToClassTopic(next);
      }
    });

    return enabled;
  }

  /// Register the reschedule callback (set once from main.dart at startup).
  void setRescheduleCallback(RescheduleCallback callback) {
    _onReschedule = callback;
  }

  /// Toggle notifications on/off and persist the choice.
  ///
  /// When enabling: requests permission and subscribes to class topic.
  /// When disabling: unsubscribes from all topics.
  ///
  /// Returns whether the toggle was successfully set to [value].
  Future<bool> toggle(bool value) async {
    state = value;
    Hive.box(kSettingsBoxName).put(_kNotificationsEnabledKey, value);
    debugLog('[FCM] notifications enabled: $value');

    final service = NotificationService.instance;
    if (value) {
      final granted = await service.requestPermission();
      if (!granted) {
        debugLog('[FCM] permission denied — disabling toggle');
        state = false;
        Hive.box(kSettingsBoxName).put(_kNotificationsEnabledKey, false);
        ref.invalidate(fcmStatusProvider);
        return false;
      }

      // Subscribe to the currently selected class topic.
      final classCode = ref.read(selectedClassProvider);
      if (classCode.isNotEmpty) {
        debugLog('[FCM] subscribing on enable: $classCode');
        await FcmService.instance.subscribeToClassTopic(classCode);
      }

      // Reschedule reminders after permission granted and topic subscribed.
      if (_onReschedule != null) {
        debugLog('[FCM] rescheduling reminders after enable');
        await _onReschedule!();
      }

      ref.invalidate(fcmStatusProvider);
      return true;
    } else {
      // Unsubscribe from all topics when disabling.
      debugLog('[FCM] disabling — unsubscribing all topics');
      await FcmService.instance.unsubscribeFromAllTopics();
      ref.invalidate(fcmStatusProvider);
      return true;
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
/// - "Belum aktif" — notifications disabled by user
/// - "Diblokir — atur di pengaturan HP" — permission denied by OS
final notificationStatusProvider = FutureProvider<String>((ref) async {
  final enabled = ref.watch(notificationEnabledProvider);
  if (!enabled) return 'Belum aktif';

  final service = NotificationService.instance;
  final isEnabled = await service.isEnabled();
  return isEnabled ? 'Aktif' : 'Diblokir — atur di pengaturan HP';
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
