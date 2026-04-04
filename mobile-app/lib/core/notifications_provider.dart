import 'package:flutter/material.dart';

import 'api_client.dart';

class NotificationData {
  NotificationData({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.messageEn,
    required this.messageAr,
    required this.timeEn,
    required this.timeAr,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String titleEn;
  final String titleAr;
  final String messageEn;
  final String messageAr;
  final String timeEn;
  final String timeAr;
  final IconData icon;
  final Color color;
  final Color bgColor;
  bool isRead;
  final DateTime createdAt;

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    final category = json['category']?.toString() ?? 'info';
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final title = json['title']?.toString() ?? 'Notification';
    final message = json['message']?.toString() ?? '';
    return NotificationData(
      id: json['id']?.toString() ?? '',
      titleEn: title,
      titleAr: title,
      messageEn: message,
      messageAr: message,
      timeEn: _timeLabel(createdAt, false),
      timeAr: _timeLabel(createdAt, true),
      icon: _iconFor(category),
      color: _colorFor(category),
      bgColor: _bgColorFor(category),
      isRead: json['is_read'] == true,
      createdAt: createdAt,
    );
  }

  static String _timeLabel(DateTime? createdAt, bool arabic) {
    if (createdAt == null) {
      return arabic ? 'الآن' : 'Just now';
    }
    final diff = DateTime.now().difference(createdAt);
    if (diff.inHours < 1) {
      return arabic ? 'الآن' : 'Just now';
    }
    if (diff.inHours < 24) {
      return arabic ? 'منذ ${diff.inHours} ساعة' : '${diff.inHours}h ago';
    }
    return arabic ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
  }

  static IconData _iconFor(String category) {
    switch (category) {
      case 'disease':
        return Icons.eco;
      case 'forecast':
        return Icons.trending_up;
      default:
        return Icons.notifications_active;
    }
  }

  static Color _colorFor(String category) {
    switch (category) {
      case 'disease':
        return const Color(0xFFF44336);
      case 'forecast':
        return const Color(0xFFFFC107);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  static Color _bgColorFor(String category) {
    switch (category) {
      case 'disease':
        return const Color(0xFFFFEBEE);
      case 'forecast':
        return const Color(0xFFFFF8E1);
      default:
        return const Color(0xFFE8F5E9);
    }
  }
}

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient() {
    loadNotifications();
  }

  final ApiClient _apiClient;
  final List<NotificationData> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

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

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
