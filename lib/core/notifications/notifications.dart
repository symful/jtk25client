/// Notifications feature — cross-platform notification service.
///
/// Provides data-update polling, class reminders, and permission management
/// for Android (WorkManager), Windows (Timer), and Web (Notification API).
library;

export 'notification_service.dart';
export 'notification_providers.dart';
export 'workmanager_callback.dart' show callbackDispatcher, kDataPollTask;
