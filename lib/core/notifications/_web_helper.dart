/// Web implementation of notification helpers using dart:html.
///
/// Provides browser Notification API access for the web platform.
// ignore_for_file: deprecated_member_use
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Whether the browser supports the Notification API.
bool webNotificationSupported() => html.Notification.supported;

/// Request browser notification permission. Returns true if granted.
Future<bool> webRequestPermission() async {
  if (!html.Notification.supported) return false;
  final result = await html.Notification.requestPermission();
  return result == 'granted';
}

/// Show a browser notification (fire-and-forget).
void webShowNotification(String title, String body) {
  if (!html.Notification.supported) return;
  // Try to show notification; ignore errors (permission may have been revoked).
  try {
    html.Notification(title, body: body);
  } catch (_) {
    // Swallow — permission may have changed since last check.
  }
}

/// Listen for page visibility changes (visibilitychange event).
///
/// Calls [onVisible] whenever the page becomes visible again.
void webStartVisibilityListener(void Function() onVisible) {
  html.document.addEventListener('visibilitychange', (_) {
    if (html.document.visibilityState == 'visible') {
      onVisible();
    }
  });
}
