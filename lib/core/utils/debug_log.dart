/// Conditional debug logging for JTK25.
///
/// Wraps [debugPrint] behind [kDebugMode] so release builds produce zero
/// log output. Prefix every call-site with a tag, e.g. `[FCM]`, `[WorkManager]`.
library;

import 'package:flutter/foundation.dart';

/// Log [message] only in debug mode.
///
/// ```dart
/// debugLog('[FCM] subscribed to topic: $topic');
/// ```
void debugLog(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(message);
  }
}
