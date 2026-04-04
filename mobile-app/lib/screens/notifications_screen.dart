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
                    child:
                        CircularProgressIndicator(color: Color(0xFF4CAF50)),
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
                          ...today.map((n) => _buildNotifCard(n, lang)),
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
                          ...earlier.map((n) => _buildNotifCard(n, lang)),
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

  Widget _buildNotifCard(NotificationData n, LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: n.bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(n.icon, size: 24, color: n.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.isRTL ? n.titleAr : n.titleEn,
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lang.isRTL ? n.messageAr : n.messageEn,
                  style: const TextStyle(
                    color: Color(0xFF424242),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lang.isRTL ? n.timeAr : n.timeEn,
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
  }
}
