/// Notifications feature — cross-platform notification service.
///
/// Provides data-update polling, class reminders, and permission management
/// for Android (WorkManager + FCM), Web (FCM + Notification API), and
/// local reminders via flutter_local_notifications.
library;

export 'notification_service.dart';
export 'notification_providers.dart';
export 'fcm_service.dart';
export 'web_push_config.dart' show kVapidKey;
export 'workmanager_callback.dart' show callbackDispatcher, kDataPollTask;
