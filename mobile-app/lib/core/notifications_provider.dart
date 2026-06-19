import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'api_client.dart';
import 'fcm_service.dart';
import 'offline_sync_notification.dart';

class NotificationData {
  NotificationData({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.messageEn,
    required this.messageAr,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.isRead = false,
    this.scanId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String titleEn;
  final String titleAr;
  final String messageEn;
  final String messageAr;
  final IconData icon;
  final Color color;
  final Color bgColor;
  bool isRead;
  final String? scanId;
  final DateTime createdAt;

  /// Computes a human-readable relative time label at call time so it always
  /// reflects the current moment (never frozen at "Just now").
  String timeLabel(bool arabic) => _timeLabel(createdAt, arabic);

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    final category = json['category']?.toString() ?? 'info';
    // Server returns UTC timestamps without a Z marker — append Z so Dart
    // treats them as UTC, then convert to local time. Without this fix the
    // difference is exactly the user's UTC offset (e.g. +3 h for Egypt).
    String ts = json['created_at']?.toString() ?? '';
    if (ts.isNotEmpty &&
        !ts.endsWith('Z') &&
        !RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(ts)) {
      ts += 'Z';
    }
    final createdAt = ts.isEmpty ? null : DateTime.tryParse(ts)?.toLocal();
    final title = json['title']?.toString() ?? 'Notification';
    final message = json['message']?.toString() ?? '';
    final metadata = json['metadata'];
    final scanId =
        json['related_scan_id']?.toString() ??
        (metadata is Map ? metadata['scan_id']?.toString() : null);
    return NotificationData(
      id: json['id']?.toString() ?? '',
      titleEn: title,
      titleAr: title,
      messageEn: message,
      messageAr: message,
      icon: _iconFor(category),
      color: _colorFor(category),
      bgColor: _bgColorFor(category),
      isRead: json['is_read'] == true,
      scanId: scanId,
      createdAt: createdAt,
    );
  }

  static String _timeLabel(DateTime? createdAt, bool arabic) {
    if (createdAt == null) {
      return arabic ? 'الآن' : 'Just now';
    }
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) {
      return arabic ? 'الآن' : 'Just now';
    }
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return arabic ? 'منذ $m دقيقة' : '${m}m ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return arabic ? 'منذ $h ساعة' : '${h}h ago';
    }
    final d = diff.inDays;
    return arabic ? 'منذ $d يوم' : '${d}d ago';
  }

  static IconData _iconFor(String category) {
    switch (category) {
      case 'disease':
        return Icons.eco;
      case 'sync':
        return Icons.sync_rounded;
      default:
        return Icons.notifications_active;
    }
  }

  static Color _colorFor(String category) {
    switch (category) {
      case 'disease':
        return const Color(0xFFF44336);
      case 'sync':
        return const Color(0xFF1976D2);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  static Color _bgColorFor(String category) {
    switch (category) {
      case 'disease':
        return const Color(0xFFFFEBEE);
      case 'sync':
        return const Color(0xFFE3F2FD);
      default:
        return const Color(0xFFE8F5E9);
    }
  }
}

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient() {
    FcmService.onForegroundMessage = _handlePushMessage;
  }

  final ApiClient _apiClient;
  final List<NotificationData> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentUserId = '';

  List<NotificationData> get notifications => List.unmodifiable(_notifications);
  List<NotificationData> get todayNotifications => _notifications
      .where((item) => DateTime.now().difference(item.createdAt).inDays < 1)
      .toList();
  List<NotificationData> get earlierNotifications => _notifications
      .where((item) => DateTime.now().difference(item.createdAt).inDays >= 1)
      .toList();
  int get unreadCount => _notifications.where((item) => !item.isRead).length;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentUserId => _currentUserId;

  void clear() {
    _notifications.clear();
    _errorMessage = null;
    notifyListeners();
  }

  void onUserChanged(String userId) {
    if (userId == _currentUserId) return;
    _currentUserId = userId;
    if (userId.isEmpty) {
      clear();
    } else {
      loadNotifications();
    }
  }

  Future<void> loadNotifications() async {
    _setLoading(true);
    try {
      final response = await _apiClient.get('/api/notifications', auth: true);
      final items =
          ((response['data'] as Map<String, dynamic>)['notifications']
                      as List<dynamic>? ??
                  [])
              .cast<Map<String, dynamic>>();
      _notifications
        ..clear()
        ..addAll(items.map(NotificationData.fromJson));
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _apiClient.put('/api/notifications/$id/read', auth: true);
      final index = _notifications.indexWhere((item) => item.id == id);
      if (index != -1) {
        _notifications[index].isRead = true;
        notifyListeners();
      }
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiClient.put('/api/notifications/read-all', auth: true);
      for (final item in _notifications) {
        item.isRead = true;
      }
      notifyListeners();
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  void addOfflineSyncNotification(OfflineSyncNotification notification) {
    final item = NotificationData(
      id: notification.id,
      titleEn: notification.titleEn,
      titleAr: notification.titleAr,
      messageEn: notification.messageEn,
      messageAr: notification.messageAr,
      icon: NotificationData._iconFor(notification.category),
      color: NotificationData._colorFor(notification.category),
      bgColor: NotificationData._bgColorFor(notification.category),
      scanId: notification.scanId,
      createdAt: notification.createdAt,
    );
    _notifications.removeWhere((existing) => existing.id == item.id);
    _notifications.insert(0, item);
    notifyListeners();
  }

  void _handlePushMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    final data = message.data;
    final category = data['category'] as String? ?? 'info';
    final scanId = data['scan_id'] as String?;
    final item = NotificationData(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      titleEn: notification.title ?? 'Notification',
      titleAr: notification.title ?? 'إشعار',
      messageEn: notification.body ?? '',
      messageAr: notification.body ?? '',
      icon: NotificationData._iconFor(category),
      color: NotificationData._colorFor(category),
      bgColor: NotificationData._bgColorFor(category),
      scanId: scanId,
    );
    _notifications.insert(0, item);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
