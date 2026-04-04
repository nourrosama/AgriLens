import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/user_provider.dart';

/// Phone login — country code +20 + phone input
class LoginPhoneScreen extends StatefulWidget {
  const LoginPhoneScreen({super.key});

  @override
  State<LoginPhoneScreen> createState() => _LoginPhoneScreenState();
}

class _LoginPhoneScreenState extends State<LoginPhoneScreen> {
  final _phoneController = TextEditingController();
  bool _isValid = false;

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

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      setState(() => _isValid = _buildPhoneNumber() != null);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
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
                  // Phone icon circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    lang.t('login.title'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    lang.t('login.subtitle'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Label
                  Text(
                    lang.t('login.phone'),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Country code + Phone input
                  Row(
                    children: [
                      Container(
                        width: 80,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 2),
                        ),
                        child: const Center(
                          child: Text(
                            '+20',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                            hintStyle: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),
                  const SizedBox(height: 32),

                  // Send OTP button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isValid && !userProvider.isLoading
                          ? () async {
                              final phone = _buildPhoneNumber();
                              if (phone == null) {
                                return;
                              }
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await context
                                  .read<UserProvider>()
                                  .sendOtp(phone);
                              if (!context.mounted) {
                                return;
                              }
                              if (ok) {
                                context.go('/login-otp');
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      userProvider.errorMessage ??
                                          'Failed to send OTP',
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isValid && !userProvider.isLoading
                            ? AppColors.primary
                            : AppColors.border,
                        foregroundColor: _isValid && !userProvider.isLoading
                            ? Colors.white
                            : AppColors.textSecondary,
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
}
