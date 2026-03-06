import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/notifications_provider.dart';

/// Notifications screen — matches TSX Notifications.tsx exactly:
/// Today / Earlier sections with colored background cards
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final notifsProvider = context.watch<NotificationsProvider>();
    final today = notifsProvider.todayNotifications;
    final earlier = notifsProvider.earlierNotifications;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go('/home'),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Transform.flip(
                    flipX: lang.isRTL,
                    child: const Icon(Icons.arrow_back, size: 28, color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  lang.t('notifications.title'),
                  style: const TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: () => notifsProvider.markAllAsRead(),
                child: Text(
                  lang.t('notifications.markAllRead'),
                  style: const TextStyle(color: AppColors.primary, fontSize: 16),
                ),
              ),
            ]),
          ),

          // Notification list
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Today
                if (today.isNotEmpty) ...[
                  Text(
                    lang.t('notifications.today'),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  ...today.map((n) => _notifCard(lang, n)),
                  const SizedBox(height: 16),
                ],

                // Earlier
                if (earlier.isNotEmpty) ...[
                  Text(
                    lang.t('notifications.earlier'),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  ...earlier.map((n) => _notifCard(lang, n)),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _notifCard(LanguageProvider lang, NotificationData n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: n.bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(n.icon, size: 24, color: n.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              lang.isRTL ? n.titleAr : n.titleEn,
              style: const TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              lang.isRTL ? n.messageAr : n.messageEn,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              lang.isRTL ? n.timeAr : n.timeEn,
              style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.7), fontSize: 12),
            ),
          ]),
        ),
      ]),
    );
  }
}
