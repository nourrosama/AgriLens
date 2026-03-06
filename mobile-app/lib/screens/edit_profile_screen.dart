import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/user_provider.dart';

/// Edit Profile screen — matches TSX EditProfile.tsx exactly.
/// Photo upload, name, email, phone (disabled), country. Success dialog on save.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  String _country = 'egypt';
  File? _photo;
  bool _showSuccess = false;

  static const _countries = [
    ('egypt', 'Egypt', 'مصر'),
    ('saudi', 'Saudi Arabia', 'المملكة العربية السعودية'),
    ('uae', 'UAE', 'الإمارات العربية المتحدة'),
    ('jordan', 'Jordan', 'الأردن'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<UserProvider>();
    _nameCtrl = TextEditingController(text: user.fullName ?? 'Ahmed Hassan');
    _emailCtrl = TextEditingController(text: user.email ?? 'ahmed.hassan@email.com');
    _phoneCtrl = TextEditingController(text: user.phone ?? '+20 123 456 7890');
    _country = user.country ?? 'egypt';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) setState(() => _photo = File(file.path));
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<UserProvider>().updateProfile(
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        country: _country,
        photoPath: _photo?.path,
      );
      setState(() => _showSuccess = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _showSuccess = false);
          context.go('/profile');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Transform.flip(
                    flipX: lang.isRTL,
                    child: const Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lang.isRTL ? 'تعديل الملف الشخصي' : 'Edit Profile',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                Text(lang.isRTL ? 'تحديث معلوماتك الشخصية' : 'Update your personal information',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              ]),
            ]),
          ),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    // Photo upload
                    Column(children: [
                      GestureDetector(
                        onTap: _pickPhoto,
                        child: Stack(children: [
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                            ),
                            child: _photo != null
                                ? ClipOval(child: Image.file(_photo!, fit: BoxFit.cover))
                                : const Icon(Icons.person, size: 56, color: AppColors.primary),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
                              ),
                              child: const Icon(Icons.upload, size: 18, color: Colors.white),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Text(lang.isRTL ? 'تغيير الصورة' : 'Change photo',
                          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                    ]),
                    const SizedBox(height: 24),

                    // Full name
                    _fieldLabel(lang.isRTL ? 'الاسم الكامل' : 'Full Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: _inputDec(''),
                      style: const TextStyle(fontSize: 16),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '' : null,
                    ),
                    const SizedBox(height: 20),

                    // Email
                    _fieldLabel(lang.isRTL ? 'البريد الإلكتروني' : 'Email'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: _inputDec(lang.isRTL ? 'أدخل البريد الإلكتروني' : 'Enter your email'),
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),

                    // Phone (disabled)
                    _fieldLabel(lang.isRTL ? 'رقم الهاتف' : 'Phone Number'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneCtrl,
                      enabled: false,
                      decoration: _inputDec('').copyWith(filled: true, fillColor: const Color(0xFFF3F4F6)),
                      style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        lang.isRTL ? 'تواصل مع الدعم لتغيير رقم الهاتف' : 'Contact support to change phone number',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Country
                    _fieldLabel(lang.isRTL ? 'الدولة' : 'Country'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _country,
                      decoration: _inputDec(null),
                      style: const TextStyle(fontSize: 16, color: Color(0xFF111827)),
                      items: _countries.map((c) => DropdownMenuItem(
                        value: c.$1,
                        child: Text(lang.isRTL ? c.$3 : c.$2),
                      )).toList(),
                      onChanged: (v) => setState(() => _country = v ?? _country),
                    ),
                    const SizedBox(height: 28),

                    // Save button
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
                          lang.isRTL ? 'حفظ التغييرات' : 'Save Changes',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),

      // Success overlay dialog
      floatingActionButton: _showSuccess
          ? IgnorePointer(
              child: Container(
                color: Colors.black54,
                constraints: const BoxConstraints.expand(),
                child: Center(
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 64, height: 64,
                        decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                        child: const Icon(Icons.check, size: 32, color: AppColors.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(lang.isRTL ? 'تم الحفظ بنجاح!' : 'Profile Updated!',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      const SizedBox(height: 8),
                      Text(lang.isRTL ? 'تم تحديث ملفك الشخصي' : 'Your profile has been updated',
                          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
                    ]),
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _fieldLabel(String label) => Align(
    alignment: Alignment.centerLeft,
    child: Text(label, style: const TextStyle(color: Color(0xFF374151), fontSize: 16, fontWeight: FontWeight.w500)),
  );

  InputDecoration _inputDec(String? hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.transparent)),
  );
}
