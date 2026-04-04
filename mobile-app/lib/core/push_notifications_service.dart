import 'dart:async';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_client.dart';

class PushNotificationsService {
  PushNotificationsService._();

  static final PushNotificationsService instance = PushNotificationsService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiClient _apiClient = ApiClient();
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) {
      unawaited(_registerToken(token));
    });

    FirebaseMessaging.onMessage.listen((message) {
      log(
        'FCM foreground message: ${message.notification?.title} ${message.notification?.body}',
        name: 'PushNotificationsService',
      );
    });
  }

  Future<void> registerCurrentDevice() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await _registerToken(token);
  }

  Future<void> unregisterCurrentDevice() async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      await _apiClient.delete(
        '/api/notifications/device-token',
        auth: true,
        body: {'token': token},
      );
    } catch (_) {
      log('Failed to unregister device token', name: 'PushNotificationsService');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await _apiClient.post(
        '/api/notifications/device-token',
        auth: true,
        body: {'token': token},
      );
    } catch (_) {
      log('Failed to register device token', name: 'PushNotificationsService');
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _initialized = false;
  }
}
