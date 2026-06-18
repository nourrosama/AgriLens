import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/user_provider.dart';

/// OTP verification — 6-digit code entry
class LoginOtpScreen extends StatefulWidget {
  const LoginOtpScreen({super.key});

  @override
  State<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends State<LoginOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  /// Guards against cascade calls when we set controller.text programmatically.
  bool _isPasting = false;

  bool get _isComplete => _controllers.every((c) => c.text.isNotEmpty);

  @override
  void initState() {
    super.initState();
    // Listen to each focus node so we select-all when a box gains focus —
    // makes it easy to overwrite a single digit without pressing backspace first.
    for (int i = 0; i < 6; i++) {
      final ctrl = _controllers[i];
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          ctrl.selection = TextSelection(
            baseOffset: 0,
            extentOffset: ctrl.text.length,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (_isPasting) return;

    // Strip everything that isn't a digit.
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 1) {
      // ── Paste detected ────────────────────────────────────────────────────
      _isPasting = true;
      for (int j = 0; j < 6; j++) {
        _controllers[j].text = j < digits.length ? digits[j] : '';
      }
      _isPasting = false;

      // Move focus to the last filled box (or box 5 if all 6 were pasted).
      final lastIdx = (digits.length - 1).clamp(0, 5);
      _focusNodes[lastIdx].requestFocus();
      setState(() {});
      return;
    }

    // ── Single character typed ─────────────────────────────────────────────
    // If the raw value contained a non-digit, replace it with the cleaned form.
    if (value != digits) {
      _isPasting = true;
      _controllers[index].text = digits;
      _controllers[index].selection = TextSelection.fromPosition(
        TextPosition(offset: digits.length),
      );
      _isPasting = false;
    }

    if (digits.isNotEmpty) {
      // Advance to next box.
      if (index < 5) _focusNodes[index + 1].requestFocus();
    } else {
      // Digit cleared (backspace) — retreat to previous box.
      if (index > 0) _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
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
                    onTap: () => context.go('/login'),
                    child: Icon(
                      lang.isRTL
                          ? Icons.arrow_forward_rounded
                          : Icons.arrow_back_rounded,
                      size: 28,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    lang.t('login.otpTitle'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userProvider.pendingEmail != null
                        ? '${lang.isRTL ? 'تم إرسال الرمز إلى' : 'Code sent to'} ${userProvider.pendingEmail}'
                        : '${lang.t('login.otpSubtitle')} ${userProvider.pendingPhone ?? '+20'}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // OTP boxes
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) {
                        return SizedBox(
                          width: 48,
                          height: 56,
                          child: TextField(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            // No maxLength — handled in _onDigitChanged so
                            // pasting a 6-digit code works correctly.
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (v) => _onDigitChanged(i, v),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Dev-mode banner: shown when Gmail is not configured
                  if (userProvider.devEmailOtp != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9C4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF9A825)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.developer_mode, size: 18, color: Color(0xFFF57F17)),
                          const SizedBox(width: 8),
                          Text(
                            'Dev code: ${userProvider.devEmailOtp}',
                            style: const TextStyle(
                              color: Color(0xFFF57F17),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Resend
                  Center(
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        lang.t('login.resend'),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),
                  const SizedBox(height: 32),

                  // Verify button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isComplete && !userProvider.isLoading
                          ? () async {
                              final otp = _controllers
                                  .map((controller) => controller.text)
                                  .join();
                              final messenger = ScaffoldMessenger.of(context);
                              final up = context.read<UserProvider>();
                              final bool ok;
                              if (up.pendingEmail != null) {
                                ok = await up.verifyEmailOtp(otp);
                              } else {
                                ok = await up.verifyOtp(otp);
                              }
                              if (!context.mounted) {
                                return;
                              }
                              if (ok) {
                                context.go('/login-success');
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      userProvider.errorMessage ??
                                          'Verification failed',
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isComplete && !userProvider.isLoading
                            ? AppColors.primary
                            : AppColors.border,
                        foregroundColor: _isComplete && !userProvider.isLoading
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                      child: Text(
                        userProvider.isLoading
                            ? lang.t('common.loading')
                            : lang.t('login.verify'),
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
}
