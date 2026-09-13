library;

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Day;
import 'package:hive_ce/hive.dart';

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
  debugPrint('FCM background message: ${message.messageId}');
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
      debugPrint('FcmService init failed: $e');
    }
  }

  Future<void> _initWeb({
    FlutterLocalNotificationsPlugin? localNotifications,
  }) async {
    if (kVapidKey.isEmpty) {
      debugPrint('FcmService: VAPID key not configured, skipping web FCM');
      return;
    }

    final token = await _messaging.getToken(vapidKey: kVapidKey);
    if (token != null) {
      debugPrint('FCM web token: ${token.substring(0, 20)}...');
      await _persistToken(token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM web token refreshed');
      _persistToken(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM foreground web message: ${message.notification?.title}');
      _handleForegroundMessage(message, localNotifications: localNotifications);
    });
  }

  Future<void> _initNative({
    FlutterLocalNotificationsPlugin? localNotifications,
  }) async {
    final token = await _messaging.getToken();
    if (token != null) {
      debugPrint('FCM native token: ${token.substring(0, 20)}...');
      await _persistToken(token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM native token refreshed');
      _persistToken(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        'FCM foreground native message: ${message.notification?.title}',
      );
      _handleForegroundMessage(message, localNotifications: localNotifications);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM message opened app: ${message.notification?.title}');
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
      debugPrint('FCM subscribed to topic: $topic');
      await _recordTopicSubscription(topic);
    } catch (e) {
      debugPrint('FCM subscribeToTopic failed for $topic: $e');
    }
  }

  /// Unsubscribe from an FCM topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('FCM unsubscribed from topic: $topic');
      await _removeTopicSubscription(topic);
    } catch (e) {
      debugPrint('FCM unsubscribeFromTopic failed for $topic: $e');
    }
  }

  /// Subscribe to the topic for the selected class.
  ///
  /// Unsubscribes from previously subscribed class topics first.
  Future<void> subscribeToClassTopic(String classCode) async {
    final previousTopics = _getSubscribedTopics();

    for (final oldTopic in previousTopics) {
      await unsubscribeFromTopic(oldTopic);
    }

    final topic = 'jtk25_$classCode';
    await subscribeToTopic(topic);
  }

  List<String> _getSubscribedTopics() {
    final box = Hive.box(kSettingsBoxName);
    final topics = box.get(_kFcmTopicsKey);
    if (topics is List) {
      return topics.cast<String>();
    }
    return [];
  }

  Future<void> _recordTopicSubscription(String topic) async {
    final box = Hive.box(kSettingsBoxName);
    final current = _getSubscribedTopics();
    if (!current.contains(topic)) {
      current.add(topic);
      await box.put(_kFcmTopicsKey, current);
    }
  }

  Future<void> _removeTopicSubscription(String topic) async {
    final box = Hive.box(kSettingsBoxName);
    final current = _getSubscribedTopics();
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
      debugPrint('FcmService getToken failed: $e');
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
      return 'Status tidak diketahui';
    }
  }
}
