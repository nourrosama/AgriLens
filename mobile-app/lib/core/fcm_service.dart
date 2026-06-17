import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

// ── Android notification channel ─────────────────────────────────────────────
const _kChannelId = 'scan_alerts';
const _kChannelName = 'Scan Alerts';
// Custom sound: place agrilens_alert.mp3 in android/app/src/main/res/raw/
// On existing installs, uninstall the app once to rebind the channel to the new sound.
const AndroidNotificationChannel _kAndroidChannel = AndroidNotificationChannel(
  _kChannelId,
  _kChannelName,
  importance: Importance.high,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('agrilens_alert'),
);

// Singleton plugin instance shared across the main isolate.
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// ── Background isolate helper ─────────────────────────────────────────────────
// Background handlers run in a separate isolate and must re-initialise everything.
Future<void> _initLocalNotificationsStandalone() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _localNotifications.initialize(
    const InitializationSettings(android: android),
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_kAndroidChannel);
}

// ── Background FCM message handler (top-level, separate isolate) ─────────────
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  await _initLocalNotificationsStandalone();
  await FcmService.showLocalNotification(
    title: message.notification?.title ?? 'AgriLens',
    body: message.notification?.body ?? '',
    scanId: message.data['scan_id'],
  );
}

// ── Local notification tap handler (top-level, required by the plugin) ────────
@pragma('vm:entry-point')
void _onLocalNotificationTap(NotificationResponse response) {
  final scanId = response.payload;
  if (scanId != null && scanId.isNotEmpty) {
    FcmService.onNotificationTap?.call(scanId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class FcmService {
  FcmService._();

  static bool _initialized = false;
  static FirebaseMessaging? _messaging;

  /// Called with the scan_id when the user taps a notification.
  /// Set this from main.dart to your GoRouter navigation call.
  static void Function(String scanId)? onNotificationTap;

  /// Called whenever FCM rotates the device token.
  /// Set by UserProvider after login to re-register the fresh token with the backend.
  static void Function(String token)? onTokenRefresh;

  /// Held when the app was opened from a terminated-state notification tap
  /// before [onNotificationTap] was registered. Call [consumePendingDeepLink]
  /// after the router is mounted to process it.
  static String? _pendingDeepLinkScanId;

  /// Called from NotificationsProvider to handle foreground FCM messages in-app.
  static void Function(RemoteMessage)? onForegroundMessage;

  // ── Initialise ─────────────────────────────────────────────────────────────
  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _messaging = FirebaseMessaging.instance;

      // Register background FCM handler.
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

      // Initialise local notifications plugin.
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      await _localNotifications.initialize(
        const InitializationSettings(android: androidSettings),
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
        onDidReceiveBackgroundNotificationResponse: _onLocalNotificationTap,
      );

      // Create the Android channel (HIGH importance → sound + heads-up banner).
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_kAndroidChannel);

      // Token refresh → re-register with the backend so stale tokens don't
      // silently drop push notifications after Android rotates the device token.
      _messaging!.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed, re-registering');
        onTokenRefresh?.call(newToken);
      });

      // Foreground FCM → show local notification (so there's a sound even in app).
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('[FCM] Foreground: ${message.notification?.title}');
        showLocalNotification(
          title: message.notification?.title ?? 'AgriLens',
          body: message.notification?.body ?? '',
          scanId: message.data['scan_id'],
        );
        onForegroundMessage?.call(message);
      });

      // App brought from background by tapping a notification.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('[FCM] Opened from notification: ${message.notification?.title}');
        final scanId = message.data['scan_id'] as String?;
        if (scanId != null && scanId.isNotEmpty) {
          onNotificationTap?.call(scanId);
        }
        onForegroundMessage?.call(message);
      });

      // App opened from a terminated-state notification — store for later because
      // the router is not mounted yet when init() runs.
      final initial = await _messaging!.getInitialMessage();
      if (initial != null) {
        _pendingDeepLinkScanId = initial.data['scan_id'] as String?;
      }

      _initialized = true;
      debugPrint('[FCM] Firebase + local notifications initialized');
    } catch (e) {
      debugPrint('[FCM] Init skipped: $e');
    }
  }

  /// Call this once after the router is mounted (e.g. via addPostFrameCallback
  /// in main()) to navigate to the scan result when the app was cold-started
  /// from a notification tap.
  static void consumePendingDeepLink() {
    final scanId = _pendingDeepLinkScanId;
    _pendingDeepLinkScanId = null;
    if (scanId != null && scanId.isNotEmpty) {
      // Defer slightly so the router finishes mounting.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onNotificationTap?.call(scanId);
      });
    }
  }

  // ── Show a local notification with sound ──────────────────────────────────
  /// Public so offline-sync code in scan_history_provider can call it directly.
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? scanId,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 & 0x7FFFFFFF,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('agrilens_alert'),
        ),
      ),
      payload: scanId ?? '',
    );
  }

  // ── FCM device token ──────────────────────────────────────────────────────
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
