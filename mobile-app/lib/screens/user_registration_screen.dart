import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/user_provider.dart';

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String? _country;
  File? _photo;

  // ── Link contact ────────────────────────────────────────────────────────────
  final _contactCtrl = TextEditingController();
  final _otpCtrl     = TextEditingController();
  bool _otpSent      = false;
  bool _linked       = false;

  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static const _countries = [
    ('egypt', 'registration.egypt'),
    ('saudi', 'registration.saudiArabia'),
    ('uae', 'registration.uae'),
    ('jordan', 'registration.jordan'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null) {
      setState(() => _photo = File(file.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _country == null) {
      return;
    }

    final ok = await context.read<UserProvider>().register(
      fullName: _nameCtrl.text.trim(),
      country: _country!,
      profilePhotoPath: _photo?.path,
    );
    if (!mounted) {
      return;
    }

    if (ok) {
      context.go('/home');
      return;
    }

    final provider = context.read<UserProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(provider.errorMessage ?? 'Failed to save profile'),
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
                  onTap: () => context.pop(),
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
                  lang.t('registration.title'),
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lang.t('registration.subtitle'),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 16,
                  ),
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
                        _label('${lang.t('registration.fullName')} *'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameCtrl,
                          style: const TextStyle(fontSize: 16),
                          decoration: _inputDecoration(
                            lang.t('registration.namePlaceholder'),
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? ''
                              : null,
                        ),
                        const SizedBox(height: 20),
                        _label('${lang.t('registration.country')} *'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _country,
                          hint: Text(
                            lang.t('registration.selectCountry'),
                            style: const TextStyle(color: Color(0xFF9CA3AF)),
                          ),
                          decoration: _inputDecoration(null),
                          items: _countries
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.$1,
                                  child: Text(lang.t(item.$2)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _country = value),
                          validator: (value) => value == null ? '' : null,
                        ),
                        const SizedBox(height: 28),
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
                                  : lang.t('registration.continue'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _LinkContactCard(
                  contactCtrl: _contactCtrl,
                  otpCtrl: _otpCtrl,
                  otpSent: _otpSent,
                  linked: _linked,
                  onSend: _sendContactOtp,
                  onVerify: _verifyContactOtp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Link contact helpers ────────────────────────────────────────────────────

  bool get _needsPhone =>
      context.read<UserProvider>().user.phone.isEmpty;

  Future<void> _sendContactOtp() async {
    final up = context.read<UserProvider>();
    final value = _contactCtrl.text.trim();
    final bool ok;
    if (_needsPhone) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      final phone = digits.length == 11 && digits.startsWith('0')
          ? '+20${digits.substring(1)}'
          : digits.length == 10
              ? '+20$digits'
              : value;
      ok = await up.sendLinkPhoneOtp(phone);
    } else {
      ok = await up.sendLinkEmailOtp(value.toLowerCase());
    }
    if (!mounted) return;
    if (ok) {
      setState(() => _otpSent = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(up.errorMessage ?? 'Failed to send code'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _verifyContactOtp() async {
    final up = context.read<UserProvider>();
    final otp = _otpCtrl.text.trim();
    final bool ok;
    if (_needsPhone) {
      ok = await up.verifyLinkPhone(otp);
    } else {
      ok = await up.verifyLinkEmail(otp);
    }
    if (!mounted) return;
    if (ok) {
      setState(() => _linked = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_needsPhone ? 'Phone linked!' : 'Email linked!'),
        backgroundColor: AppColors.primary,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(up.errorMessage ?? 'Invalid code'),
        backgroundColor: AppColors.error,
      ));
    }
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

// ── Link Contact Card ─────────────────────────────────────────────────────────

class _LinkContactCard extends StatelessWidget {
  const _LinkContactCard({
    required this.contactCtrl,
    required this.otpCtrl,
    required this.otpSent,
    required this.linked,
    required this.onSend,
    required this.onVerify,
  });

  final TextEditingController contactCtrl;
  final TextEditingController otpCtrl;
  final bool otpSent;
  final bool linked;
  final VoidCallback onSend;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final up   = context.watch<UserProvider>();
    final lang = context.watch<LanguageProvider>();

    final needsPhone = up.user.phone.isEmpty;
    final needsEmail = up.user.email.isEmpty;

    // Both already set — nothing to show
    if (!needsPhone && !needsEmail) return const SizedBox.shrink();

    if (linked) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            needsPhone ? 'Phone number linked ✓' : 'Email linked ✓',
            style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
          ),
        ]),
      );
    }

    final label    = needsPhone ? (lang.isRTL ? 'أضف رقم هاتفك (اختياري)' : 'Add your phone number (optional)') : (lang.isRTL ? 'أضف بريدك الإلكتروني (اختياري)' : 'Add your email address (optional)');
    final hint     = needsPhone ? '+20XXXXXXXXXX' : 'you@example.com';
    final btnLabel = otpSent ? (lang.isRTL ? 'تحقق' : 'Verify') : (lang.isRTL ? 'إرسال رمز' : 'Send Code');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(needsPhone ? Icons.phone_outlined : Icons.email_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF374151))),
          ]),
          const SizedBox(height: 14),
          if (!otpSent) ...[
            TextField(
              controller: contactCtrl,
              keyboardType: needsPhone ? TextInputType.phone : TextInputType.emailAddress,
              inputFormatters: needsPhone ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)] : [],
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),
          ] else ...[
            Text(
              lang.isRTL ? 'أدخل الرمز المرسل' : 'Enter the 6-digit code',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              style: const TextStyle(fontSize: 18, letterSpacing: 6, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '------',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), letterSpacing: 4),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: up.isLoading ? null : (otpSent ? onVerify : onSend),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(up.isLoading ? '...' : btnLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
