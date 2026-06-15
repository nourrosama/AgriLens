// Generated from google-services.json for project agrilens-f370c
// To regenerate: dart pub global activate flutterfire_cli && flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase web is not configured for AgriLens.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase is not configured for ${defaultTargetPlatform.name}.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDibDEXptMSN54_mImjziB9kunmaPSQ5FE',
    appId: '1:323361901377:android:fd5ed61a6fed23c15cefc0',
    messagingSenderId: '323361901377',
    projectId: 'agrilens-f370c',
    storageBucket: 'agrilens-f370c.firebasestorage.app',
  );
}
