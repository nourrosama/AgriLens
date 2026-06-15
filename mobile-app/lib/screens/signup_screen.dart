import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/user_provider.dart';

/// New-user registration screen — collects name, country, and phone BEFORE OTP.
/// On success, navigates to /login-otp to complete verification.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  File? _photo;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String? _buildPhone() {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('0')) return '+20${digits.substring(1)}';
    if (digits.length == 10) return '+20$digits';
    return null;
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null) setState(() => _photo = File(file.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _buildPhone();
    if (phone == null) return;

    final provider = context.read<UserProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final ok = await provider.signup(
      fullName: _nameCtrl.text.trim(),
      country: 'egypt',
      phone: phone,
      email: _emailCtrl.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      context.go('/login-otp');
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(provider.errorMessage ?? 'Failed to send OTP'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0FDF4), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => context.go('/auth-choice'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.flip(
                        flipX: lang.isRTL,
                        child: const Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lang.t('common.back'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  lang.t('signup.title'),
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lang.t('signup.subtitle'),
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Profile photo
                        GestureDetector(
                          onTap: _pickPhoto,
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFDCFCE7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: _photo != null
                                        ? ClipOval(
                                            child: Image.file(
                                              _photo!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person,
                                            size: 48,
                                            color: AppColors.primary,
                                          ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.upload,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                lang.t('registration.profilePhoto'),
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Full name
                        _label('${lang.t('registration.fullName')} *'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameCtrl,
                          style: const TextStyle(fontSize: 16),
                          decoration: _inputDecoration(lang.t('registration.namePlaceholder')),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? '' : null,
                        ),
                        const SizedBox(height: 20),

                        // Email
                        _label(lang.t('registration.email')),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontSize: 16),
                          decoration: _inputDecoration(lang.t('registration.emailPlaceholder')),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final valid = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim());
                            return valid ? null : '';
                          },
                        ),
                        const SizedBox(height: 20),

                        // Phone
                        _label('${lang.t('signup.phone')} *'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 80,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFD1D5DB),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  '+20',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(11),
                                ],
                                style: const TextStyle(fontSize: 16),
                                decoration: _inputDecoration(
                                  lang.t('signup.phonePlaceholder'),
                                ),
                                validator: (_) =>
                                    _buildPhone() == null ? '' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Submit
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: userProvider.isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              userProvider.isLoading
                                  ? lang.t('common.loading')
                                  : lang.t('signup.sendCode'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Login link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              lang.t('signup.alreadyHaveAccount'),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => context.go('/login'),
                              child: Text(
                                lang.t('signup.loginLink'),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  InputDecoration _inputDecoration(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
      );
}
