library;

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Day;
import 'package:hive_ce/hive.dart';

import '../utils/debug_log.dart';
import 'notification_service.dart';
import 'web_push_config.dart';
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
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugLog('[FCM] background message: ${message.messageId}');
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

  /// Initialize FCM for the current platform.
  ///
  /// On Android, requests notification permission and retrieves the FCM token.
  /// On web, requests permission with vapidKey for push support.
  /// On unsupported platforms, gracefully returns.
  Future<void> init({
    FlutterLocalNotificationsPlugin? localNotifications,
  }) async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      if (kIsWeb) {
        await _initWeb(localNotifications: localNotifications);
      } else {
        await _initNative(localNotifications: localNotifications);
      }
    } catch (e) {
      debugLog('[FCM] init failed: $e');
    }
  }

  Future<void> _initWeb({
    FlutterLocalNotificationsPlugin? localNotifications,
  }) async {
    if (kVapidKey.isEmpty) {
      debugLog('[FCM] VAPID key not configured, skipping web FCM');
      return;
    }

    final token = await _messaging.getToken(vapidKey: kVapidKey);
    if (token != null) {
      debugLog('[FCM] web token: ${token.substring(0, 20)}...');
      await _persistToken(token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      debugLog('[FCM] web token refreshed');
      _persistToken(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugLog('[FCM] foreground web message: ${message.notification?.title}');
      _handleForegroundMessage(message, localNotifications: localNotifications);
    });
  }

  Future<void> _initNative({
    FlutterLocalNotificationsPlugin? localNotifications,
  }) async {
    final token = await _messaging.getToken();
    if (token != null) {
      debugLog('[FCM] native token: ${token.substring(0, 20)}...');
      await _persistToken(token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      debugLog('[FCM] native token refreshed');
      _persistToken(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugLog(
        '[FCM] foreground native message: ${message.notification?.title}',
      );
      _handleForegroundMessage(message, localNotifications: localNotifications);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugLog('[FCM] message opened app: ${message.notification?.title}');
    });
  }

  void _handleForegroundMessage(
    RemoteMessage message, {
    FlutterLocalNotificationsPlugin? localNotifications,
  }) {
    final title = message.notification?.title ?? 'JTK25';
    final body = message.notification?.body ?? 'Pembaruan tersedia';

    if (!kIsWeb && localNotifications != null) {
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

    // Idempotency: no-op if already subscribed to this class.
    if (_currentSubscribedClass == classCode) {
      debugLog('[FCM] already subscribed to class $classCode, no-op');
      return;
    }

    debugLog('[FCM] subscribeToClassTopic: $classCode');

    // Snapshot before iterating to avoid CastList concurrent-modification.
    final previousTopics = _snapshotTopics();

    for (final oldTopic in previousTopics) {
      await unsubscribeFromTopic(oldTopic);
    }

    final topic = 'jtk25_$classCode';
    await subscribeToTopic(topic);
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
      if (kIsWeb && kVapidKey.isEmpty) return null;
      final token = kIsWeb
          ? await _messaging.getToken(vapidKey: kVapidKey)
          : await _messaging.getToken();
      if (token != null) await _persistToken(token);
      return token;
    } catch (e) {
      debugLog('[FCM] getToken failed: $e');
      return null;
    }
  }

  /// Check if FCM is supported on the current platform.
  bool get isSupported => !kIsWeb || kVapidKey.isNotEmpty;

  /// Get human-readable push status in Bahasa Indonesia.
  Future<String> pushStatusText() async {
    if (!isSupported) return 'Belum aktif di browser ini';
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
