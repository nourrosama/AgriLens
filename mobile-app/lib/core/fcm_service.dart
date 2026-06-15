import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

// Must be a top-level function — called by FCM when app is in background/terminated.
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  // No UI access here. Firebase is already initialized by the time this runs.
  debugPrint('[FCM] Background message: ${message.notification?.title}');
}

class FcmService {
  FcmService._();

  static bool _initialized = false;
  static FirebaseMessaging? _messaging;

  // Set this callback from NotificationsProvider to handle foreground messages.
  static void Function(RemoteMessage)? onForegroundMessage;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _messaging = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('[FCM] Foreground message: ${message.notification?.title}');
        onForegroundMessage?.call(message);
      });

      // When user taps a notification that opened the app from background.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('[FCM] Opened from notification: ${message.notification?.title}');
        onForegroundMessage?.call(message);
      });

      _initialized = true;
      debugPrint('[FCM] Firebase initialized successfully');
    } catch (e) {
      // Placeholder google-services.json in use — FCM silently disabled.
      // Replace android/app/google-services.json with the real file from Firebase Console.
      debugPrint('[FCM] Firebase init skipped: $e');
    }
  }

  /// Returns the FCM device token, or null if Firebase is not configured.
  static Future<String?> getToken() async {
    if (!_initialized || _messaging == null) return null;
    try {
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      final token = await _messaging!.getToken();
      debugPrint('[FCM] Device token: $token');
      return token;
    } catch (e) {
      debugPrint('[FCM] getToken failed: $e');
      return null;
    }
  }

  static bool get isReady => _initialized;
}
