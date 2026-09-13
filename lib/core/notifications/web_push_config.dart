/// Web push VAPID key configuration for FCM on web.
///
/// The VAPID key is required for web push notifications. This key is PUBLIC
/// by design (VAPID keys are not secrets — they identify the push service to
/// the browser) and is safe to commit to a public repository.
///
/// To regenerate:
/// 1. Go to Firebase Console → Project Settings → Cloud Messaging
/// 2. Under "Web Push certificates", click "Generate Key Pair"
/// 3. Copy the key and paste it below as [kVapidKey]
library;

/// VAPID key for web push notifications.
///
/// This key is PUBLIC by design (not a secret) — safe to commit.
/// To regenerate: Firebase Console → Project Settings → Cloud Messaging
/// → Web Push certificates → Generate Key Pair.
const String kVapidKey =
    'BME2GlPdcuNcJp8VCaqLuJ7LkYeZPcgjnKiRFifoBbnJOTYT2kIYNaovMf6W_lS7XUURcon8kfObkIqRfKTIbgQ';
