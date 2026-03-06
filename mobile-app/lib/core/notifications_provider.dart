import 'package:flutter/material.dart';

/// Notification data model
class NotificationData {
  final int id;
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
}

/// Provider that manages notifications.
/// Ready to connect to backend — see TODO comments for API integration points.
class NotificationsProvider extends ChangeNotifier {
  final List<NotificationData> _notifications = [
    NotificationData(
      id: 1,
      titleEn: 'Moderate Risk Detected',
      titleAr: 'تم اكتشاف خطر متوسط',
      messageEn: 'Field B - North section showing early symptoms',
      messageAr: 'الحقل ب - القسم الشمالي يظهر أعراض مبكرة',
      timeEn: '2 hours ago',
      timeAr: 'منذ ساعتين',
      icon: Icons.warning_rounded,
      color: const Color(0xFFFFC107),
      bgColor: const Color(0xFFFFF3E0),
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    NotificationData(
      id: 2,
      titleEn: 'Risk Forecast Updated',
      titleAr: 'تحديث توقعات الخطر',
      messageEn: 'Disease risk will increase on Thursday',
      messageAr: 'سيزداد خطر المرض يوم الخميس',
      timeEn: '5 hours ago',
      timeAr: 'منذ 5 ساعات',
      icon: Icons.trending_up,
      color: const Color(0xFF4CAF50),
      bgColor: const Color(0xFFE8F5E9),
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    NotificationData(
      id: 3,
      titleEn: 'Weather Alert',
      titleAr: 'تنبيه طقس',
      messageEn: 'Heavy rain expected tomorrow',
      messageAr: 'أمطار غزيرة متوقعة غداً',
      timeEn: '1 day ago',
      timeAr: 'منذ يوم',
      icon: Icons.cloud,
      color: const Color(0xFF2196F3),
      bgColor: const Color(0xFFE3F2FD),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    NotificationData(
      id: 4,
      titleEn: 'Treatment Completed',
      titleAr: 'اكتمل العلاج',
      messageEn: 'Field A treatment successfully applied',
      messageAr: 'تم تطبيق علاج الحقل أ بنجاح',
      timeEn: '2 days ago',
      timeAr: 'منذ يومين',
      icon: Icons.check_circle,
      color: const Color(0xFF4CAF50),
      bgColor: const Color(0xFFE8F5E9),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    NotificationData(
      id: 5,
      titleEn: 'New Disease Detected',
      titleAr: 'تم اكتشاف مرض جديد',
      messageEn: 'Late blight found in Field C',
      messageAr: 'تم العثور على اللفحة المتأخرة في الحقل ج',
      timeEn: '3 days ago',
      timeAr: 'منذ 3 أيام',
      icon: Icons.eco,
      color: const Color(0xFFF44336),
      bgColor: const Color(0xFFFFEBEE),
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  List<NotificationData> get notifications => List.unmodifiable(_notifications);

  List<NotificationData> get todayNotifications =>
      _notifications.where((n) => DateTime.now().difference(n.createdAt).inDays < 1).toList();

  List<NotificationData> get earlierNotifications =>
      _notifications.where((n) => DateTime.now().difference(n.createdAt).inDays >= 1).toList();

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// TODO: Replace with API call to PUT /api/notifications/:id/read
  void markAsRead(int id) {
    final notif = _notifications.firstWhere((n) => n.id == id, orElse: () => _notifications.first);
    notif.isRead = true;
    notifyListeners();
  }

  /// TODO: Replace with API call to PUT /api/notifications/read-all
  void markAllAsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  /// TODO: Replace with API call to POST /api/notifications
  void addNotification(NotificationData notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }
}
