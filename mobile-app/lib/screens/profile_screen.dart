import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/core/fields_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/widgets/bottom_nav.dart';
import 'package:agrilens/widgets/chatbot_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final userProvider = context.watch<UserProvider>();
    final fieldsProvider = context.watch<FieldsProvider>();
    final scanProvider = context.watch<ScanHistoryProvider>();
    final user = userProvider.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(children: [
                GestureDetector(onTap: () => context.go('/home'),
                  child: Padding(padding: const EdgeInsets.all(8),
                      child: Transform.flip(flipX: lang.isRTL, child: const Icon(Icons.arrow_back, size: 28, color: AppColors.textSecondary)))),
                const SizedBox(width: 16),
                Text(lang.t('profile.title'), style: const TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w600)),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  _userInfo(lang, user, fieldsProvider, scanProvider),
                  const SizedBox(height: 24),
                  _subscriptionCard(context, lang),
                  const SizedBox(height: 24),
                  _menuOptions(context, lang),
                  const SizedBox(height: 24),
                  _logoutBtn(context, lang, userProvider),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ]),
          const ChatbotButton(),
        ]),
      ),
      bottomNavigationBar: const BottomNav(active: 'profile'),
    );
  }

  Widget _userInfo(LanguageProvider lang, UserData user, FieldsProvider fieldsProvider, ScanHistoryProvider scanProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Row(children: [
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
            child: user.profilePhotoPath != null
                ? ClipOval(
                    child: Image.asset(
                      user.profilePhotoPath!,
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40, color: AppColors.primary),
                    ),
                  )
                : const Icon(Icons.person, size: 40, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.fullName.isNotEmpty ? user.fullName : (lang.isRTL ? 'أحمد حسن' : 'Ahmed Hassan'),
                style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(user.phone.isNotEmpty ? user.phone : '+20 123 456 7890',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ])),
        ]),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _stat('${scanProvider.totalScans}', lang.t('nav.scan'))),
          Expanded(child: _stat('${fieldsProvider.fields.length}', lang.t('nav.fields'))),
          Expanded(child: _stat('${fieldsProvider.averageHealth}${lang.t('units.percent')}', lang.t('fields.healthScore'))),
        ]),
      ]),
    );
  }

  Widget _stat(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(color: AppColors.primaryDark, fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
    ]);
  }

  Widget _subscriptionCard(BuildContext context, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(lang.t('subscription.premium'), style: const TextStyle(color: Colors.white, fontSize: 18)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
            child: Text(lang.isRTL ? 'نشط' : 'Active', style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(lang.isRTL ? 'فحوصات غير محدودة وتوقعات دقيقة' : 'Unlimited scans and forecasting',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => context.push('/active-subscription'),
          child: Text(lang.isRTL ? 'عرض تفاصيل الاشتراك ←' : 'View subscription details →',
              style: const TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.underline)),
        ),
      ]),
    );
  }

  Widget _menuOptions(BuildContext context, LanguageProvider lang) {
    final items = [
      [Icons.settings, lang.t('profile.accountSettings'), '/settings'],
      [Icons.credit_card, lang.t('profile.subscription'), '/subscription-plans'],
      [Icons.help_outline, lang.t('profile.helpSupport'), '/settings'],
      [Icons.info_outline, lang.t('profile.about'), '/settings'],
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.value;
          return Column(children: [
            GestureDetector(
              onTap: () => context.push(i[2] as String),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Icon(i[0] as IconData, size: 24, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(i[1] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 18))),
                  Transform.flip(flipX: lang.isRTL, child: const Icon(Icons.chevron_right, size: 24, color: Color(0xFF9E9E9E))),
                ]),
              ),
            ),
            if (e.key < items.length - 1) const Divider(height: 0),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _logoutBtn(BuildContext context, LanguageProvider lang, UserProvider userProvider) {
    return GestureDetector(
      onTap: () {
        userProvider.logout();
        context.go('/');
      },
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.logout, size: 24, color: Color(0xFFF44336)),
          const SizedBox(width: 8),
          Text(lang.t('profile.logout'), style: const TextStyle(color: Color(0xFFF44336), fontSize: 18)),
        ]),
      ),
    );
  }
}
