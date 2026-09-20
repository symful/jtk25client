library;

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Day;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../utils/debug_log.dart';
import 'notification_service.dart';
import '../../features/settings/data/settings_data.dart';

/// Hive key for the FCM token.
const String _kFcmTokenKey = 'fcm_token';

/// Hive key for FCM topic subscriptions.
const String _kFcmTopicsKey = 'fcm_topics';

/// Handle background messages from FCM.
///
/// This MUST be a top-level function (not inside a class) and annotated
/// with `@pragma("vm:entry-point")` so the Dart VM can invoke it from
/// a background isolate.
///
/// When a `schedule_update` data message arrives in the background, this
/// handler initializes Hive + flutter_local_notifications and shows a
/// local notification so the user is alerted even if the app is killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugLog('[FCM] background message: ${message.messageId}');

  final type = message.data['type'] as String?;
  if (type == null || type.isEmpty) return;

  const updatableTypes = {
    'schedule_update',
    'calendar_update',
    'pengganti_update',
    'announcement_update',
    'dosen_update',
    'room_update',
  };
  if (!updatableTypes.contains(type)) return;

  try {
    await Hive.initFlutter();
    await Hive.openBox(kSettingsBoxName);
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await plugin.initialize(settings: initSettings);

    // Create the notification channel in the background isolate.
    // Android 8+ requires a channel to display notifications.
    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          kNotificationChannelId,
          kNotificationChannelName,
          description: kNotificationChannelDesc,
        ),
      );
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        kNotificationChannelId,
        kNotificationChannelName,
        channelDescription: kNotificationChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    final title = message.notification?.title ?? 'JTK25';
    final body = message.notification?.body ?? 'Ada pembaruan baru.';
    await plugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: details,
    );
    debugLog('[FCM] background: showed $type notification');
  } catch (e) {
    debugLog('[FCM] background handler failed: $e');
  }
}

/// Firebase Cloud Messaging service for JTK25.
///
/// Handles token management, topic subscriptions, foreground message display,
/// and graceful degradation on unsupported platforms.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  /// In-memory cache of the currently subscribed class code.
  ///
  /// Used for idempotency: [subscribeToClassTopic] is a no-op when the
  /// requested [classCode] matches this value, preventing unsub→sub churn
  /// on every UI rebuild.
  String? _currentSubscribedClass;

  static VoidCallback? onScheduleUpdate;
  static VoidCallback? onCalendarUpdate;
  static VoidCallback? onPenggantiUpdate;
  static VoidCallback? onRescheduleReminders;

  /// Initialize FCM for Android.
  Future<void> init({
    FlutterLocalNotificationsPlugin? localNotifications,
  }) async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await _initNative(localNotifications: localNotifications);
    } catch (e) {
      debugLog('[FCM] init failed: $e');
    }
  }

  Future<void> _initNative({
    FlutterLocalNotificationsPlugin? localNotifications,
  }) async {
    final token = await _messaging.getToken();
    if (token != null) {
      debugLog('[FCM] token: ${token.substring(0, 20)}...');
      await _persistToken(token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      debugLog('[FCM] token refreshed');
      _persistToken(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugLog('[FCM] foreground message: ${message.notification?.title}');
      _handleForegroundMessage(message, localNotifications: localNotifications);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugLog('[FCM] message opened app: ${message.notification?.title}');
      _handleDataMessage(message);
    });
  }

  void _handleForegroundMessage(
    RemoteMessage message, {
    FlutterLocalNotificationsPlugin? localNotifications,
  }) {
    final title = message.notification?.title ?? 'JTK25';
    final body = message.notification?.body ?? 'Pembaruan tersedia';

    if (localNotifications != null) {
      final details = const NotificationDetails(
        android: AndroidNotificationDetails(
          kNotificationChannelId,
          kNotificationChannelName,
          channelDescription: kNotificationChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      localNotifications.show(
        id: title.hashCode.abs() % 2147483647,
        title: title,
        body: body,
        notificationDetails: details,
      );
    }

    // Process data payload for schedule updates.
    _handleDataMessage(message);
  }

  void _handleDataMessage(RemoteMessage message) {
    final type = message.data['type'] as String?;
    debugLog('[FCM] data message type: $type');

    switch (type) {
      case 'schedule_update':
        onScheduleUpdate?.call();
        onRescheduleReminders?.call();
      case 'calendar_update':
        onCalendarUpdate?.call();
        onRescheduleReminders?.call();
      case 'pengganti_update':
        onPenggantiUpdate?.call();
        onRescheduleReminders?.call();
    }
  }

  Future<void> _persistToken(String token) async {
    final box = Hive.box(kSettingsBoxName);
    await box.put(_kFcmTokenKey, token);
  }

  /// Subscribe to an FCM topic.
  ///
  /// Topics are used for class-specific data-update notifications.
  /// The topic name is derived from the class code (e.g. "jtk25_D3-2A").
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugLog('[FCM] subscribed to topic: $topic');
      await _recordTopicSubscription(topic);
    } catch (e) {
      debugLog('[FCM] subscribeToTopic failed for $topic: $e');
    }
  }

  /// Unsubscribe from an FCM topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugLog('[FCM] unsubscribed from topic: $topic');
      await _removeTopicSubscription(topic);
    } catch (e) {
      debugLog('[FCM] unsubscribeFromTopic failed for $topic: $e');
    }
  }

  /// Unsubscribe from all currently subscribed FCM topics.
  ///
  /// Snapshots the topic list before iterating to avoid concurrent
  /// modification of the underlying Hive CastList.
  Future<void> unsubscribeFromAllTopics() async {
    // Snapshot to avoid CastList concurrent-modification during iteration.
    final previousTopics = _snapshotTopics();
    debugLog('[FCM] unsubscribing from ${previousTopics.length} topics');
    for (final oldTopic in previousTopics) {
      await unsubscribeFromTopic(oldTopic);
    }
    _currentSubscribedClass = null;
  }

  /// Subscribe to the topic for the selected class.
  ///
  /// **Idempotent**: if [classCode] is the same as the currently subscribed
  /// class, this is a no-op — prevents unsub→sub churn on UI rebuilds.
  ///
  /// Unsubscribes from previously subscribed class topics first,
  /// then subscribes to the new class topic.
  Future<void> subscribeToClassTopic(String classCode) async {
    if (classCode.isEmpty) {
      debugLog('[FCM] subscribeToClassTopic: empty classCode, skipping');
      return;
    }

    if (_currentSubscribedClass == classCode) {
      debugLog('[FCM] already subscribed to class $classCode, no-op');
      return;
    }

    debugLog('[FCM] subscribeToClassTopic: $classCode');

    final previousTopics = _snapshotTopics();
    for (final oldTopic in previousTopics) {
      await unsubscribeFromTopic(oldTopic);
    }

    await subscribeToTopic('jtk25_$classCode');
    await subscribeToTopic('jtk25_global');
    _currentSubscribedClass = classCode;
  }

  /// Return a safe [List<String>] snapshot of subscribed topics from Hive.
  ///
  /// The Hive `CastList` returned by `box.get()` is a live view — iterating
  /// it while mutating the underlying box causes
  /// `Concurrent modification during iteration`. Calling `.toList()` creates
  /// a detached copy that is safe to iterate.
  List<String> _snapshotTopics() {
    final box = Hive.box(kSettingsBoxName);
    final topics = box.get(_kFcmTopicsKey);
    if (topics is List) {
      return topics.cast<String>().toList();
    }
    return [];
  }

  Future<void> _recordTopicSubscription(String topic) async {
    final box = Hive.box(kSettingsBoxName);
    final current = _snapshotTopics();
    if (!current.contains(topic)) {
      current.add(topic);
      await box.put(_kFcmTopicsKey, current);
    }
  }

  Future<void> _removeTopicSubscription(String topic) async {
    final box = Hive.box(kSettingsBoxName);
    final current = _snapshotTopics();
    current.remove(topic);
    await box.put(_kFcmTopicsKey, current);
  }

  /// Get the current FCM token (from Hive cache or live).
  Future<String?> getToken() async {
    final box = Hive.box(kSettingsBoxName);
    final cached = box.get(_kFcmTokenKey) as String?;
    if (cached != null) return cached;

    try {
      final token = await _messaging.getToken();
      if (token != null) await _persistToken(token);
      return token;
    } catch (e) {
      debugLog('[FCM] getToken failed: $e');
      return null;
    }
  }

  bool get isSupported => true;

  /// Get human-readable push status in Bahasa Indonesia.
  Future<String> pushStatusText() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          return 'Aktif';
        case AuthorizationStatus.provisional:
          return 'Aktif';
        case AuthorizationStatus.denied:
          return 'Diblokir oleh sistem';
        case AuthorizationStatus.notDetermined:
          return 'Belum diatur';
        case AuthorizationStatus.deniedPermanently:
          return 'Diblokir permanen — atur di pengaturan HP';
      }
    } catch (e) {
      debugLog('[FCM] pushStatusText failed: $e');
      return 'Status tidak diketahui';
    }
  }
}
