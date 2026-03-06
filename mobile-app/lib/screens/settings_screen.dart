import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          _header(context, lang),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionTitle(lang.t('settings.account')),
                const SizedBox(height: 12),
                _accountSection(context, lang),
                const SizedBox(height: 24),
                _sectionTitle(lang.t('settings.privacy')),
                const SizedBox(height: 12),
                _privacySection(context, lang),
                const SizedBox(height: 24),
                _sectionTitle(lang.t('settings.help')),
                const SizedBox(height: 12),
                _helpSection(context, lang),
                const SizedBox(height: 24),
                _appInfo(lang),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _header(BuildContext context, LanguageProvider lang) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.go('/profile'),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Transform.flip(
              flipX: lang.isRTL,
              child: const Icon(Icons.arrow_back, size: 28, color: AppColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(lang.t('settings.title'),
            style: const TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
    );
  }

  Widget _accountSection(BuildContext context, LanguageProvider lang) {
    return _menuGroup([
      _menuItem(Icons.person, lang.t('settings.editProfile'), lang,
          onTap: () => context.push('/edit-profile')),
      _languageToggle(lang),
      _menuItem(Icons.notifications, lang.t('settings.notifications'), lang,
          onTap: () => context.push('/notifications')),
    ]);
  }

  Widget _privacySection(BuildContext context, LanguageProvider lang) {
    return _menuGroup([
      _menuItem(Icons.shield, lang.t('settings.dataPrivacy'), lang,
          onTap: () => context.push('/data-privacy')),
      _menuItem(Icons.description, lang.t('settings.termsConditions'), lang,
          onTap: () => context.push('/terms-conditions')),
    ]);
  }

  Widget _helpSection(BuildContext context, LanguageProvider lang) {
    return _menuGroup([
      _menuItem(Icons.menu_book, lang.t('settings.tutorial'), lang,
          onTap: () => context.push('/app-tutorial')),
      _menuItem(Icons.chat, lang.t('settings.contactSupport'), lang,
          onTap: () => context.push('/contact-support')),
      _menuItem(Icons.help_outline, lang.t('settings.faq'), lang,
          onTap: () => context.push('/faq')),
    ]);
  }

  Widget _menuGroup(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        for (int i = 0; i < items.length; i++) ...[
          items[i],
          if (i < items.length - 1) const Divider(height: 0),
        ],
      ]),
    );
  }

  Widget _menuItem(IconData icon, String label, LanguageProvider lang, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Icon(icon, size: 24, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 18))),
          Transform.flip(
            flipX: lang.isRTL,
            child: const Icon(Icons.chevron_right, size: 24, color: Color(0xFF9E9E9E)),
          ),
        ]),
      ),
    );
  }

  Widget _languageToggle(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        const Icon(Icons.language, size: 24, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(child: Text(lang.t('settings.language'),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 18))),
        GestureDetector(
          onTap: () => lang.setLanguage(lang.languageCode == 'en' ? 'ar' : 'en'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              lang.languageCode == 'en' ? 'العربية' : 'English',
              style: const TextStyle(color: AppColors.primary, fontSize: 16),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _appInfo(LanguageProvider lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Text(lang.t('app.name'),
            style: const TextStyle(color: AppColors.primaryDark, fontSize: 18)),
        const SizedBox(height: 4),
        Text(lang.t('app.tagline'),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 12),
        const Text('Version 1.0.0',
            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
      ]),
    );
  }
}
