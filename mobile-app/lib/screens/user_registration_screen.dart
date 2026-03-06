import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/user_provider.dart';

/// User Registration screen — matches TSX UserRegistration.tsx exactly.
/// Green gradient background, profile photo upload, full name, country.
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

  static const _countries = [
    ('egypt', 'Egypt', 'مصر'),
    ('saudi', 'Saudi Arabia', 'المملكة العربية السعودية'),
    ('uae', 'UAE', 'الإمارات العربية المتحدة'),
    ('jordan', 'Jordan', 'الأردن'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) setState(() => _photo = File(file.path));
  }

  void _submit() {
    if (_formKey.currentState!.validate() && _country != null) {
      context.read<UserProvider>().register(
        fullName: _nameCtrl.text.trim(),
        country: _country!,
        profilePhotoPath: _photo?.path,
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Back button + header
              GestureDetector(
                onTap: () => context.pop(),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Transform.flip(
                    flipX: lang.isRTL,
                    child: const Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Text(lang.t('common.back'), style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                ]),
              ),
              const SizedBox(height: 24),
              Text(
                lang.isRTL ? 'إنشاء حساب' : 'Create Account',
                style: const TextStyle(color: Color(0xFF111827), fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                lang.isRTL ? 'أكمل ملفك الشخصي للبدء' : 'Complete your profile to get started',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16),
              ),
              const SizedBox(height: 32),

              // Form card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    // Profile photo
                    Column(children: [
                      GestureDetector(
                        onTap: _pickPhoto,
                        child: Stack(children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: _photo != null
                                ? ClipOval(child: Image.file(_photo!, fit: BoxFit.cover))
                                : const Icon(Icons.person, size: 48, color: AppColors.primary),
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
                              child: const Icon(Icons.upload, size: 16, color: Colors.white),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang.isRTL ? 'اختر صورة شخصية' : 'Choose profile photo',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Full name
                    _label(lang.isRTL ? 'الاسم الكامل *' : 'Full Name *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(fontSize: 16),
                      decoration: _inputDecoration(lang.isRTL ? 'أدخل اسمك الكامل' : 'Enter your full name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '' : null,
                    ),
                    const SizedBox(height: 20),

                    // Country
                    _label(lang.isRTL ? 'الدولة *' : 'Country *'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _country,
                      hint: Text(lang.isRTL ? 'اختر دولتك' : 'Select your country', style: const TextStyle(color: Color(0xFF9CA3AF))),
                      decoration: _inputDecoration(null),
                      items: _countries.map((c) => DropdownMenuItem(
                        value: c.$1,
                        child: Text(lang.isRTL ? c.$3 : c.$2),
                      )).toList(),
                      onChanged: (v) => setState(() => _country = v),
                      validator: (v) => (v == null) ? '' : null,
                    ),
                    const SizedBox(height: 28),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          lang.isRTL ? 'متابعة' : 'Continue',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: const TextStyle(color: Color(0xFF374151), fontSize: 16, fontWeight: FontWeight.w500)),
  );

  InputDecoration _inputDecoration(String? hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.transparent)),
  );
}
