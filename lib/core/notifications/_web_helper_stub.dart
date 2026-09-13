/// Stub implementation for non-web platforms.
///
/// When the app runs on Android or Windows, these functions are no-ops.
/// The real implementation lives in `_web_helper.dart` (web only).
library;

bool webNotificationSupported() => false;

Future<bool> webRequestPermission() async => false;

void webShowNotification(String title, String body) {}

void webStartVisibilityListener(void Function() onVisible) {}
