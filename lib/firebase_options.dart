/// Firebase configuration for JTK25 client.
///
/// Hand-written from Firebase console config (flutterfire configure not used).
/// This file provides platform-specific Firebase options via
/// [DefaultFirebaseOptions].
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Default [FirebaseOptions] for use with Firebase apps.
///
/// To regenerate this file, run `flutterfire configure --project=numeric-lead-265602`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBsJ_hpqNs069WddnD_QFWoAfhWZf6RD0E',
    appId: '1:273058937677:android:3f1989af79995c02ae5504',
    messagingSenderId: '273058937677',
    projectId: 'numeric-lead-265602',
    databaseURL: 'https://numeric-lead-265602.firebaseio.com',
    storageBucket: 'numeric-lead-265602.firebasestorage.app',
  );
}
