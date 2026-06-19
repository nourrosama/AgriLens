class OfflineSyncNotification {
  OfflineSyncNotification({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.messageEn,
    required this.messageAr,
    this.category = 'sync',
    this.scanId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String titleEn;
  final String titleAr;
  final String messageEn;
  final String messageAr;
  final String category;
  final String? scanId;
  final DateTime createdAt;
}
