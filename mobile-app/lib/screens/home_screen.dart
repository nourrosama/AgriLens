import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/notifications_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/core/weather_provider.dart';
import 'package:agrilens/widgets/bottom_nav.dart';
import 'package:agrilens/widgets/chatbot_button.dart';
import 'package:agrilens/widgets/plan_gate.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Timer _greetingTimer;

  @override
  void initState() {
    super.initState();
    // Tick every minute so the greeting switches at the exact boundary hour.
    _greetingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _greetingTimer.cancel();
    super.dispose();
  }

  String _greetingKey() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'home.goodMorning';
    if (hour >= 12 && hour < 18) return 'home.goodAfternoon';
    return 'home.goodEvening';
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();
    final scans = context.watch<ScanHistoryProvider>();
    final notifications = context.watch<NotificationsProvider>();
    final weather = context.watch<WeatherProvider>();

    // Compute health from scan data
    final totalScans = scans.totalScans;
    final activeDiseases = scans.activeDiseasesCount;
    final healthPercent = totalScans > 0
        ? ((totalScans - activeDiseases) / totalScans * 100).round()
        : 100;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Header ────────────────────────────────────
              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.of(context).padding.top + 12,
                  24,
                  12,
                ),
                child: Row(
                  children: [
                    // Logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 40,
                        height: 40,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.eco,
                            color: Color(0xFF4CAF50),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.t('app.name'),
                            style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${lang.t(_greetingKey())}, ${user.fullName ?? lang.t('home.farmer')}',
                            style: const TextStyle(
                              color: Color(0xFF424242),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Notification bell
                    GestureDetector(
                      onTap: () => context.push('/notifications'),
                      child: Stack(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.notifications_outlined,
                              size: 24,
                              color: Color(0xFF424242),
                            ),
                          ),
                          if (notifications.unreadCount > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFC107),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: const Color(0xFFE0E0E0)),

              // ── Trial Banner ───────────────────────────────
              if (!user.isSubscribed && user.trialDaysLeft > 0)
                GestureDetector(
                  onTap: () => context.push('/subscription-plans'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    color: const Color(0xFFE8F5E9),
                    child: Row(
                      children: [
                        const Icon(Icons.card_giftcard, color: Color(0xFF2E7D32), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${lang.t('subscription.trialActive')} · ${user.trialDaysLeft} ${lang.t('subscription.trialDaysLeft')}',
                            style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 13),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Color(0xFF2E7D32), size: 18),
                      ],
                    ),
                  ),
                ),

              // ── Body ──────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                  child: Column(
                    children: [
                      // Plant Health Status
                      _buildCard(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  lang.t('home.plantHealth'),
                                  style: const TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Icon(
                                  Icons.eco_rounded,
                                  color: Color(0xFF4CAF50),
                                  size: 24,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: healthPercent / 100,
                                      minHeight: 12,
                                      backgroundColor: const Color(0xFFF5F5F5),
                                      valueColor: const AlwaysStoppedAnimation(
                                        Color(0xFF4CAF50),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '$healthPercent${lang.t('units.percent')}',
                                  style: const TextStyle(
                                    color: Color(0xFF4CAF50),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                lang.t('home.healthyStatus'),
                                style: const TextStyle(
                                  color: Color(0xFF424242),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Quick Scan Button
                      GestureDetector(
                        onTap: () => context.push('/crop-select'),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF4CAF50,
                                ).withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.t('home.quickScan'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lang.t('home.quickScanDesc'),
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Active Alerts
                      _buildCard(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  lang.t('home.activeAlerts'),
                                  style: const TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.push('/notifications'),
                                  child: Text(
                                    lang.t('home.viewAll'),
                                    style: const TextStyle(
                                      color: Color(0xFF4CAF50),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // First alert: most recent notification, or empty state
                            if (notifications.notifications.isNotEmpty)
                              _buildAlertBubble(
                                lang.isRTL
                                    ? notifications.notifications.first.titleAr
                                    : notifications.notifications.first.titleEn,
                                lang.isRTL
                                    ? notifications.notifications.first.messageAr
                                    : notifications.notifications.first.messageEn,
                                notifications.notifications.first.bgColor,
                                notifications.notifications.first.icon,
                                notifications.notifications.first.color,
                              )
                            else
                              _buildEmptyAlerts(lang),
                            // Second alert: second notification if available
                            if (notifications.notifications.length > 1) ...[
                              const SizedBox(height: 12),
                              _buildAlertBubble(
                                lang.isRTL
                                    ? notifications.notifications[1].titleAr
                                    : notifications.notifications[1].titleEn,
                                lang.isRTL
                                    ? notifications.notifications[1].messageAr
                                    : notifications.notifications[1].messageEn,
                                notifications.notifications[1].bgColor,
                                notifications.notifications[1].icon,
                                notifications.notifications[1].color,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Weather Widget
                      _buildCard(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  lang.t('home.weatherToday'),
                                  style: const TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Icon(
                                  Icons.cloud_rounded,
                                  color: Color(0xFF4CAF50),
                                  size: 24,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${weather.temperature}${lang.t('units.celsius')}',
                                      style: const TextStyle(
                                        color: Color(0xFF2E7D32),
                                        fontSize: 36,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      weather.condition(lang.isRTL).isNotEmpty
                                          ? weather.condition(lang.isRTL)
                                          : lang.t('home.partlyCloudy'),
                                      style: const TextStyle(
                                        color: Color(0xFF424242),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${lang.t('home.humidity')}: ${weather.humidity}${lang.t('units.percent')}',
                                      style: const TextStyle(
                                        color: Color(0xFF424242),
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '${lang.t('home.wind')}: ${weather.wind} ${lang.t('units.kmh')}',
                                      style: const TextStyle(
                                        color: Color(0xFF424242),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 1,
                              color: const Color(0xFFE0E0E0),
                            ),
                            const SizedBox(height: 16),
                            // 7-day forecast bars
                            SizedBox(
                              height: 108,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: weather.forecast.map((day) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      const Icon(
                                        Icons.eco_rounded,
                                        size: 16,
                                        color: Color(0xFF4CAF50),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: 8,
                                        height: ((day.temp / 45) * 56)
                                            .clamp(8.0, 56.0)
                                            .toDouble(),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${day.temp}°',
                                        style: const TextStyle(
                                          color: Color(0xFF424242),
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        lang.isRTL ? day.dayAr : day.dayEn,
                                        style: const TextStyle(
                                          color: Color(0xFF424242),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Quick Actions Grid
                      Row(
                        children: [
                          // Scan History — all users
                          Expanded(
                            child: GestureDetector(
                              onTap: () => context.push('/scan-history'),
                              child: _buildCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.history_rounded,
                                      size: 40,
                                      color: Color(0xFF4CAF50),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      lang.t('home.scanHistory'),
                                      style: const TextStyle(
                                        color: Color(0xFF2E7D32),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // My Fields — Professional only
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (user.plan == 'professional') {
                                  context.push('/fields');
                                } else {
                                  showPlanGateSheet(
                                    context,
                                    requiredPlan: 'professional',
                                    isRTL: lang.isRTL,
                                  );
                                }
                              },
                              child: _buildCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Icon(
                                          Icons.eco_rounded,
                                          size: 40,
                                          color: user.plan == 'professional'
                                              ? const Color(0xFF4CAF50)
                                              : const Color(0xFFBDBDBD),
                                        ),
                                        if (user.plan != 'professional')
                                          const Positioned(
                                            right: -4,
                                            top: -4,
                                            child: Icon(
                                              Icons.lock_rounded,
                                              size: 16,
                                              color: Color(0xFF9E9E9E),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      lang.t('home.myFields'),
                                      style: TextStyle(
                                        color: user.plan == 'professional'
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFF9E9E9E),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Disease Articles card ──────────────────────────────
                      _buildArticlesCard(context, lang, user),
                      const SizedBox(height: 24),

                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom Nav
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNav(active: 'home'),
          ),

          // Chatbot FAB
          const ChatbotButton(),
        ],
      ),
    );
  }

  /// Disease Articles card — available to Premium & Professional users.
  /// Free users see a locked prompt with an upgrade link.
  Widget _buildArticlesCard(
    BuildContext context,
    LanguageProvider lang,
    UserProvider user,
  ) {
    final isRTL = lang.isRTL;
    final canAccess =
        user.plan == 'premium' || user.plan == 'professional';

    if (canAccess) {
      return GestureDetector(
        onTap: () => context.push('/articles-browser'),
        child: _buildCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.article_rounded,
                  color: Color(0xFF2E7D32),
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRTL ? 'مقالات الأمراض' : 'Disease Articles',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRTL
                          ? 'تصفح المقالات العلمية والمجتمعية'
                          : 'Browse scientific & community articles',
                      style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF4CAF50),
                size: 24,
              ),
            ],
          ),
        ),
      );
    }

    // Free plan — locked card
    return _buildCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_outline, color: Color(0xFF9E9E9E), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRTL ? 'مقالات الأمراض' : 'Disease Articles',
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isRTL
                      ? 'متاح لمشتركي بريميوم والاحترافي'
                      : 'Available on Premium & Professional',
                  style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => context.push('/subscription-plans'),
                  child: Text(
                    isRTL ? 'ترقية الخطة ←' : 'Upgrade plan →',
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _greeting(LanguageProvider lang) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return lang.t('home.goodMorning');
    if (hour >= 12 && hour < 17) return lang.t('home.goodAfternoon');
    if (hour >= 17 && hour < 21) return lang.t('home.goodEvening');
    return lang.t('home.goodNight');
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: child,
    );
  }

  Widget _buildAlertBubble(
    String title,
    String subtitle,
    Color bgColor,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF424242),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: const Color(0xFF424242).withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAlerts(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: Color(0xFF9E9E9E), size: 20),
          const SizedBox(width: 12),
          Text(
            lang.isRTL ? 'لا توجد تنبيهات نشطة' : 'No active alerts',
            style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

