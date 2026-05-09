import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/app_config.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _initialised = false;
  String _country = 'egypt';
  File? _photo;
  String? _existingPhotoPath;

  static const _countries = [
    ('egypt', 'Egypt', 'مصر'),
    ('saudi', 'Saudi Arabia', 'السعودية'),
    ('uae', 'UAE', 'الإمارات'),
    ('jordan', 'Jordan', 'الأردن'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) {
      return;
    }
    final user = context.read<UserProvider>();
    _nameCtrl.text = user.fullName ?? '';
    _emailCtrl.text = user.email ?? '';
    _phoneCtrl.text = user.phone ?? '';
    _country = user.country ?? 'egypt';
    _existingPhotoPath = user.photoPath;
    _initialised = true;
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
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null) {
      setState(() => _photo = File(file.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final ok = await context.read<UserProvider>().updateProfile(
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      country: _country,
      photoPath: _photo?.path ?? _existingPhotoPath,
    );
    if (!mounted) {
      return;
    }
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().t('editProfile.successMessage'),
          ),
        ),
      );
      context.go('/profile');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<UserProvider>().errorMessage ?? 'Update failed',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Transform.flip(
                        flipX: lang.isRTL,
                        child: const Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.t('editProfile.title'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        lang.t('editProfile.subtitle'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
                    child: Column(
                      children: [
                        Column(
                          children: [
                            GestureDetector(
                              onTap: _pickPhoto,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(child: _buildAvatar()),
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
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.upload,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              lang.t('registration.changePhoto'),
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _fieldLabel(lang.t('editProfile.name')),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: _inputDec(),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? ' '
                              : null,
                        ),
                        const SizedBox(height: 20),
                        _fieldLabel(lang.t('editProfile.email')),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDec(
                            hint: lang.t('editProfile.emailPlaceholder'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _fieldLabel(lang.t('editProfile.phone')),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneCtrl,
                          enabled: false,
                          decoration: _inputDec().copyWith(
                            filled: true,
                            fillColor: const Color(0xFFF3F4F6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _fieldLabel(lang.t('editProfile.country')),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _country,
                          decoration: _inputDec(),
                          items: _countries
                              .map(
                                (country) => DropdownMenuItem<String>(
                                  value: country.$1,
                                  child: Text(
                                    lang.isRTL ? country.$3 : country.$2,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _country = value ?? _country),
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
                            child: userProvider.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    lang.t('editProfile.saveChanges'),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (_photo != null) {
      return Image.file(_photo!, fit: BoxFit.cover);
    }
    final path = _existingPhotoPath;
    if (path == null || path.isEmpty) {
      return const Icon(Icons.person, size: 56, color: AppColors.primary);
    }
    if (path.startsWith('/uploads/')) {
      return Image.network(
        '${AppConfig.apiBaseUrl}$path',
        headers: const {'ngrok-skip-browser-warning': 'true'},
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.person, size: 56, color: AppColors.primary),
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        headers: const {'ngrok-skip-browser-warning': 'true'},
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.person, size: 56, color: AppColors.primary),
      );
    }
    if (File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover);
    }
    return const Icon(Icons.person, size: 56, color: AppColors.primary);
  }

  Widget _fieldLabel(String label) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF374151),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  InputDecoration _inputDec({String? hint}) => InputDecoration(
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
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.transparent),
    ),
  );
}
