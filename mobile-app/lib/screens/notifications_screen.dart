import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final notifs = _buildNotifs(lang);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(children: [
              GestureDetector(onTap: () => context.go('/home'),
                child: Padding(padding: const EdgeInsets.all(8),
                    child: Transform.flip(flipX: lang.isRTL, child: const Icon(Icons.arrow_back, size: 28, color: AppColors.textSecondary)))),
              const SizedBox(width: 16),
              Expanded(child: Text(lang.t('notifications.title'), style: const TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w600))),
              GestureDetector(child: Text(lang.t('notifications.markAllRead'), style: const TextStyle(color: AppColors.primary, fontSize: 16))),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lang.t('notifications.today'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                const SizedBox(height: 12),
                ...notifs.sublist(0, 2).map(_notifCard),
                const SizedBox(height: 24),
                Text(lang.t('notifications.earlier'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                const SizedBox(height: 12),
                ...notifs.sublist(2).map(_notifCard),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _notifCard(_Notif n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: n.bg, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(n.icon, size: 24, color: n.color),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n.title, style: const TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(n.message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          Text(n.time, style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
        ])),
      ]),
    );
  }

  List<_Notif> _buildNotifs(LanguageProvider lang) => [
    _Notif(Icons.warning_rounded, lang.isRTL ? 'تم اكتشاف خطر متوسط' : 'Moderate Risk Detected',
        lang.isRTL ? 'الحقل ب - القسم الشمالي يظهر أعراض مبكرة' : 'Field B - North section showing early symptoms',
        lang.isRTL ? 'منذ ساعتين' : '2 hours ago', const Color(0xFFFFC107), const Color(0xFFFFF3E0)),
    _Notif(Icons.trending_up, lang.isRTL ? 'تحديث توقعات الخطر' : 'Risk Forecast Updated',
        lang.isRTL ? 'سيزداد خطر المرض يوم الخميس' : 'Disease risk will increase on Thursday',
        lang.isRTL ? 'منذ 5 ساعات' : '5 hours ago', AppColors.primary, const Color(0xFFE8F5E9)),
    _Notif(Icons.cloud, lang.isRTL ? 'تنبيه طقس' : 'Weather Alert',
        lang.isRTL ? 'أمطار غزيرة متوقعة غداً' : 'Heavy rain expected tomorrow',
        lang.isRTL ? 'منذ يوم' : '1 day ago', const Color(0xFF2196F3), const Color(0xFFE3F2FD)),
    _Notif(Icons.check_circle, lang.isRTL ? 'اكتمل العلاج' : 'Treatment Completed',
        lang.isRTL ? 'تم تطبيق علاج الحقل أ بنجاح' : 'Field A treatment successfully applied',
        lang.isRTL ? 'منذ يومين' : '2 days ago', AppColors.primary, const Color(0xFFE8F5E9)),
    _Notif(Icons.eco, lang.isRTL ? 'تم اكتشاف مرض جديد' : 'New Disease Detected',
        lang.isRTL ? 'تم العثور على اللفحة المتأخرة في الحقل ج' : 'Late blight found in Field C',
        lang.isRTL ? 'منذ 3 أيام' : '3 days ago', const Color(0xFFF44336), const Color(0xFFFFEBEE)),
  ];
}

class _Notif {
  final IconData icon; final String title, message, time; final Color color, bg;
  _Notif(this.icon, this.title, this.message, this.time, this.color, this.bg);
}
