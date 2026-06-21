import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/app_config.dart';
import 'package:agrilens/core/fields_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/bottom_nav.dart';
import 'package:agrilens/widgets/chatbot_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Reload data every time the profile screen is opened.
    // The providers already loaded at startup, but the call may have failed
    // (backend not running, token expired, CORS on web, etc.).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ScanHistoryProvider>().loadScans();
      context.read<FieldsProvider>().loadFields();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<ScanHistoryProvider>().loadScans(),
      context.read<FieldsProvider>().loadFields(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final userProvider = context.watch<UserProvider>();
    final fieldsProvider = context.watch<FieldsProvider>();
    final scanProvider = context.watch<ScanHistoryProvider>();
    final user = userProvider.user;

    final hasError =
        (scanProvider.errorMessage != null || fieldsProvider.errorMessage != null) &&
        scanProvider.totalScans == 0 &&
        fieldsProvider.fields.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/home'),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Transform.flip(
                            flipX: lang.isRTL,
                            child: const Icon(
                              Icons.arrow_back,
                              size: 28,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        lang.t('profile.title'),
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Error banner (shown when backend unreachable)
                if (hasError)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: const Color(0xFFFFF3E0),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off,
                            color: Color(0xFFE65100), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lang.isRTL
                                ? 'تعذر الاتصال بالخادم. تأكد أن تطبيق الخادم يعمل.'
                                : 'Could not reach server. Make sure your backend is running.',
                            style: const TextStyle(
                              color: Color(0xFFE65100),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _refresh,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.refresh,
                                color: Color(0xFFE65100), size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _refresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _userInfo(context, lang, user, fieldsProvider, scanProvider),
                          const SizedBox(height: 24),
                          _accountSummary(lang, user),
                          const SizedBox(height: 24),
                          _planSection(context, lang, user),
                          const SizedBox(height: 24),
                          _menuOptions(context, lang),
                          const SizedBox(height: 24),
                          _logoutBtn(context, lang, userProvider),
                          const SizedBox(height: 12),
                          _deleteAccountBtn(context, lang, userProvider),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const ChatbotButton(),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(active: 'profile'),
    );
  }

  Widget _userInfo(
    BuildContext context,
    LanguageProvider lang,
    UserData user,
    FieldsProvider fieldsProvider,
    ScanHistoryProvider scanProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(child: _buildAvatar(user.profilePhotoPath)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName.isNotEmpty
                          ? user.fullName
                          : (lang.isRTL ? 'حساب جديد' : 'New account'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.phone.isNotEmpty ? user.phone : '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    if (user.country.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.country,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          scanProvider.isLoading
              ? const SizedBox(
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/scan-history'),
                        child: _stat(
                          '${scanProvider.totalScans}',
                          lang.t('nav.scan'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _stat(
                        '${fieldsProvider.fields.length}',
                        lang.t('nav.fields'),
                      ),
                    ),
                    Expanded(
                      child: _stat(
                        '${fieldsProvider.averageHealth}${lang.t('units.percent')}',
                        lang.t('fields.healthScore'),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? path) {
    if (path == null || path.isEmpty) {
      return const Icon(Icons.person, size: 40, color: AppColors.primary);
    }
    if (path.startsWith('/uploads/')) {
      return Image.network(
        '${AppConfig.apiBaseUrl}$path',
        headers: const {'ngrok-skip-browser-warning': 'true'},
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.person, size: 40, color: AppColors.primary),
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        headers: const {'ngrok-skip-browser-warning': 'true'},
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.person, size: 40, color: AppColors.primary),
      );
    }
    if (!kIsWeb && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover);
    }
    return const Icon(Icons.person, size: 40, color: AppColors.primary);
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }

  Widget _accountSummary(LanguageProvider lang, UserData user) {
    final planLabel = user.plan.isEmpty ? 'free' : user.plan;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lang.isRTL ? 'ملخص الحساب' : 'Account summary',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  planLabel.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user.profileCompleted
                ? (lang.isRTL
                      ? 'الملف الشخصي مكتمل ويمكنك استخدام الفحص والحقول والتقارير.'
                      : 'Your profile is complete and ready for scans, fields, and reports.')
                : (lang.isRTL
                      ? 'أكمل ملفك الشخصي للوصول إلى كل المزايا الأساسية.'
                      : 'Complete your profile to unlock the core workflow.'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planSection(BuildContext context, LanguageProvider lang, UserData user) {
    final isRTL = lang.isRTL;
    final plan = user.plan.isEmpty ? 'free' : user.plan;
    final isPro = plan == 'professional';

    // ── Subscription card ─────────────────────────────────────────────────────
    Widget subCard;
    if (plan == 'free') {
      subCard = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFCC02)),
        ),
        child: Row(
          children: [
            const Icon(Icons.upgrade_rounded,
                color: Color(0xFFFF8F00), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRTL ? 'أنت على الخطة المجانية' : 'You\'re on the Free plan',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7B5800),
                        fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isRTL
                        ? 'قم بالترقية للوصول إلى التحليلات والتقارير والمزيد'
                        : 'Upgrade to unlock analytics, reports & more',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF9E7000), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => context.push('/subscription-plans'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(isRTL ? 'ترقية' : 'Upgrade',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    } else {
      subCard = GestureDetector(
        onTap: () => context.push('/subscription-plans'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isPro
                ? const Color(0xFFF3E5F5)
                : const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isPro
                    ? const Color(0xFFCE93D8)
                    : const Color(0xFF90CAF9)),
          ),
          child: Row(
            children: [
              Icon(
                isPro ? Icons.workspace_premium_rounded : Icons.star_rounded,
                color: isPro
                    ? const Color(0xFF7B1FA2)
                    : const Color(0xFF1565C0),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPro
                          ? (isRTL ? 'خطة المحترف' : 'Professional Plan')
                          : (isRTL ? 'خطة بريميوم' : 'Premium Plan'),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPro
                              ? const Color(0xFF4A148C)
                              : const Color(0xFF0D47A1),
                          fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isRTL
                          ? 'إدارة اشتراكك'
                          : 'Manage your subscription',
                      style: TextStyle(
                          color: isPro
                              ? const Color(0xFF7B1FA2)
                              : const Color(0xFF1565C0),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        subCard,
      ],
    );
  }

  Widget _menuOptions(BuildContext context, LanguageProvider lang) {
    final items = [
      (Icons.edit_outlined, lang.t('profile.editProfile'), '/edit-profile'),
      (
        Icons.settings_outlined,
        lang.t('profile.accountSettings'),
        '/settings',
      ),
      (
        Icons.star_rounded,
        lang.isRTL ? 'المفضلة' : 'Favourites',
        '/favourites',
      ),
      (
        Icons.support_agent_outlined,
        lang.t('profile.helpSupport'),
        '/contact-support',
      ),
      (Icons.menu_book_outlined, lang.t('profile.about'), '/app-tutorial'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final item = entry.value;
          return Column(
            children: [
              GestureDetector(
                onTap: () => context.push(item.$3),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(item.$1,
                          size: 24, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.$2,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Transform.flip(
                        flipX: lang.isRTL,
                        child: const Icon(
                          Icons.chevron_right,
                          size: 24,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (entry.key < items.length - 1) const Divider(height: 0),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _logoutBtn(
    BuildContext context,
    LanguageProvider lang,
    UserProvider userProvider,
  ) {
    return GestureDetector(
      onTap: () async {
        await userProvider.logout();
        if (context.mounted) {
          context.go('/');
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 24, color: Color(0xFFF44336)),
            const SizedBox(width: 8),
            Text(
              lang.t('profile.logout'),
              style:
                  const TextStyle(color: Color(0xFFF44336), fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
  Widget _deleteAccountBtn(
    BuildContext context,
    LanguageProvider lang,
    UserProvider userProvider,
  ) {
    return GestureDetector(
      onTap: () => _confirmDeleteAccount(context, lang, userProvider),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFCDD2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_forever_outlined, size: 24, color: Color(0xFFF44336)),
            const SizedBox(width: 8),
            Text(
              lang.isRTL ? 'حذف الحساب' : 'Delete Account',
              style: const TextStyle(color: Color(0xFFF44336), fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    LanguageProvider lang,
    UserProvider userProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.isRTL ? 'حذف الحساب' : 'Delete Account'),
        content: Text(
          lang.isRTL
              ? 'هل أنت متأكد؟ سيتم حذف جميع بياناتك نهائياً ولا يمكن استرجاعها.'
              : 'Are you sure? All your data will be permanently deleted and cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang.isRTL ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF44336)),
            child: Text(lang.isRTL ? 'نعم، احذف حسابي' : 'Yes, delete my account'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final apiClient = ApiClient();
      await apiClient.delete('/api/auth/me', auth: true);
      await userProvider.logout();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.isRTL ? 'فشل حذف الحساب: $e' : 'Failed to delete account: $e')),
        );
      }
    }
  }

}