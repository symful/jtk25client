/// Web implementation of notification helpers using package:web.
///
/// Provides browser Notification API access for the web platform.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool webNotificationSupported() => true;

Future<bool> webRequestPermission() async {
  if (!webNotificationSupported()) return false;
  try {
    final result = await web.Notification.requestPermission().toDart;
    return result.toString() == 'granted';
  } catch (_) {
    return false;
  }
}

void webShowNotification(String title, String body) {
  if (!webNotificationSupported()) return;
  try {
    web.Notification(title, web.NotificationOptions(body: body));
  } catch (_) {
    // Permission may have changed since last check.
  }
}

void webStartVisibilityListener(void Function() onVisible) {
  void handler(JSAny event) {
    if (web.document.visibilityState == 'visible') {
      onVisible();
    }
  }

  web.document.addEventListener('visibilitychange', handler.toJS);
}
