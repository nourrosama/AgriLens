import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/notifications_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final notifProv = context.watch<NotificationsProvider>();
    final today = notifProv.todayNotifications;
    final earlier = notifProv.earlierNotifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Header ────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
              8,
              MediaQuery.of(context).padding.top + 8,
              24,
              16,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 28,
                    color: Color(0xFF424242),
                  ),
                ),
                Expanded(
                  child: Text(
                    lang.t('notifications.title'),
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => notifProv.markAllAsRead(),
                  child: Text(
                    lang.t('notifications.markAllRead'),
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFE0E0E0)),

          // ── Body ──────────────────────────
          Expanded(
            child: notifProv.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  )
                : RefreshIndicator(
                    color: const Color(0xFF4CAF50),
                    onRefresh: () => notifProv.loadNotifications(),
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        // Today
                        if (today.isNotEmpty) ...[
                          Text(
                            lang.t('notifications.today'),
                            style: const TextStyle(
                              color: Color(0xFF424242),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...today.map(
                            (n) => _buildNotifCard(context, n, lang),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Earlier
                        if (earlier.isNotEmpty) ...[
                          Text(
                            lang.t('notifications.earlier'),
                            style: const TextStyle(
                              color: Color(0xFF424242),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...earlier.map(
                            (n) => _buildNotifCard(context, n, lang),
                          ),
                        ],

                        // Empty state
                        if (today.isEmpty && earlier.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.notifications_none_rounded,
                                  size: 80,
                                  color: Color(0xFFE0E0E0),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  lang.isRTL
                                      ? 'لا توجد إشعارات'
                                      : 'No notifications yet',
                                  style: const TextStyle(
                                    color: Color(0xFF9E9E9E),
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifCard(
    BuildContext context,
    NotificationData n,
    LanguageProvider lang,
  ) {
    final isRead = n.isRead;
    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : n.bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeadingIcon(n, isRead),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        lang.isRTL ? n.titleAr : n.titleEn,
                        style: TextStyle(
                          color: isRead
                              ? const Color(0xFF757575)
                              : const Color(0xFF2E7D32),
                          fontSize: 16,
                          fontWeight: isRead
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: n.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lang.isRTL ? n.messageAr : n.messageEn,
                  style: TextStyle(
                    color: isRead
                        ? const Color(0xFF9E9E9E)
                        : const Color(0xFF424242),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  n.timeLabel(lang.isRTL),
                  style: TextStyle(
                    color: const Color(0xFF424242).withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final scanId = n.scanId;
    return GestureDetector(
      onTap: () {
        context.read<NotificationsProvider>().markAsRead(n.id);
        if (scanId != null && scanId.isNotEmpty) {
          context.push('/scan-result', extra: scanId);
        }
      },
      child: card,
    );
  }

  Widget _buildLeadingIcon(NotificationData n, bool isRead) {
    if (n.actorName.isNotEmpty) {
      final hasPhoto = n.actorPhotoUrl.isNotEmpty;
      final initial = n.actorName[0].toUpperCase();
      return CircleAvatar(
        radius: 20,
        backgroundColor: isRead ? const Color(0xFFE0E0E0) : n.bgColor,
        backgroundImage: hasPhoto ? NetworkImage(n.actorPhotoUrl) : null,
        child: hasPhoto
            ? null
            : Text(
                initial,
                style: TextStyle(
                  color: isRead ? const Color(0xFF9E9E9E) : n.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isRead ? const Color(0xFFF5F5F5) : n.bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        n.icon,
        size: 20,
        color: isRead ? const Color(0xFFBDBDBD) : n.color,
      ),
    );
  }
}
