import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/user_provider.dart';

/// Login screen — lets the user choose between Phone OTP and Email OTP.
class LoginPhoneScreen extends StatefulWidget {
  const LoginPhoneScreen({super.key});

  @override
  State<LoginPhoneScreen> createState() => _LoginPhoneScreenState();
}

class _LoginPhoneScreenState extends State<LoginPhoneScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Phone tab ────────────────────────────────────────────────────────────
  final _phoneController = TextEditingController();
  bool _phoneValid = false;

  String? _buildPhoneNumber() {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('0')) {
      return '+20${digits.substring(1)}';
    }
    if (digits.length == 10) {
      return '+20$digits';
    }
    return null;
  }

  // ── Email tab ────────────────────────────────────────────────────────────
  final _emailController = TextEditingController();
  bool _emailValid = false;

  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _phoneController.addListener(
      () => setState(() => _phoneValid = _buildPhoneNumber() != null),
    );
    _emailController.addListener(
      () => setState(
        () => _emailValid = _emailRe.hasMatch(_emailController.text.trim()),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _sendPhoneOtp(UserProvider up) async {
    final phone = _buildPhoneNumber();
    if (phone == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await up.sendOtp(phone);
    if (!mounted) return;
    if (ok) {
      context.go('/login-otp');
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(up.errorMessage ?? 'Failed to send OTP'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _sendEmailOtp(UserProvider up) async {
    final email = _emailController.text.trim().toLowerCase();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await up.sendEmailOtp(email);
    if (!mounted) return;
    if (ok) {
      context.go('/login-otp');
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(up.errorMessage ?? 'Failed to send verification code'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final userProvider = context.watch<UserProvider>();
    final isPhone = _tabController.index == 0;
    final canSubmit = (isPhone ? _phoneValid : _emailValid) && !userProvider.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  96,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => context.go('/auth-choice'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.flip(
                          flipX: lang.isRTL,
                          child: const Icon(Icons.arrow_back,
                              size: 20, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lang.t('common.back'),
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Icon
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (_, __) => Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _tabController.index == 0
                            ? Icons.phone_rounded
                            : Icons.email_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    lang.t('login.title'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang.isRTL
                        ? 'اختر طريقة تسجيل الدخول'
                        : 'Choose how to receive your code',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // ── Tab bar ──────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      onTap: (_) => setState(() {}),
                      indicator: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.textSecondary,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone_rounded, size: 18),
                              const SizedBox(width: 6),
                              Text(lang.isRTL ? 'هاتف' : 'Phone'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.email_rounded, size: 18),
                              const SizedBox(width: 6),
                              Text(lang.isRTL ? 'بريد' : 'Email'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Tab content ──────────────────────────────────────
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (_, __) => _tabController.index == 0
                        ? _phoneInput(lang)
                        : _emailInput(lang),
                  ),

                  const Spacer(),
                  const SizedBox(height: 32),

                  // ── Send button ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canSubmit
                          ? () {
                              if (_tabController.index == 0) {
                                _sendPhoneOtp(userProvider);
                              } else {
                                _sendEmailOtp(userProvider);
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            canSubmit ? AppColors.primary : AppColors.border,
                        foregroundColor:
                            canSubmit ? Colors.white : AppColors.textSecondary,
                      ),
                      child: Text(
                        userProvider.isLoading
                            ? lang.t('common.loading')
                            : lang.t('login.sendOTP'),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Phone input widget ────────────────────────────────────────────────────

  Widget _phoneInput(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.t('login.phone'),
          style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 16,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: const Center(
                child: Text('+20',
                    style: TextStyle(
                        fontSize: 16, color: AppColors.textPrimary)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: lang.t('login.phonePlaceholder'),
                  hintStyle:
                      const TextStyle(color: AppColors.textSecondary),
                  counterText: '',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Email input widget ────────────────────────────────────────────────────

  Widget _emailInput(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.isRTL ? 'البريد الإلكتروني' : 'Email address',
          style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 16,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            hintText: lang.isRTL
                ? 'example@mail.com'
                : 'you@example.com',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon:
                const Icon(Icons.email_outlined, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          lang.isRTL
              ? 'سنرسل إليك رمز التحقق على هذا البريد'
              : 'We\'ll send a 6-digit code to this address',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}
