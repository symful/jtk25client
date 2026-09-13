/// Web push VAPID key configuration for FCM on web.
///
/// The VAPID key is required for web push notifications. To generate one:
/// 1. Go to Firebase Console → Project Settings → Cloud Messaging
/// 2. Under "Web Push certificates", click "Generate Key Pair"
/// 3. Copy the key and paste it below as [kVapidKey]
///
/// When the key is empty, the app gracefully reports that web push is
/// not configured ("Push web belum dikonfigurasi").
library;

/// VAPID key for web push notifications.
///
/// Generate a new one in Firebase Console:
/// Project Settings → Cloud Messaging → Web Push certificates → Generate Key Pair.
const String kVapidKey = '';
