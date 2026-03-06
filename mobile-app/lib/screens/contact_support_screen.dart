import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

/// Contact Support screen — matches TSX ContactSupport.tsx exactly.
/// 3 info cards (email, phone, hours), contact form with success dialog.
class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _showSuccess = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      setState(() => _showSuccess = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _showSuccess = false);
          context.pop();
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
                Text(lang.isRTL ? 'تواصل مع الدعم' : 'Contact Support',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                Text(lang.isRTL ? 'نحن هنا للمساعدة' : "We're here to help",
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              ]),
            ]),
          ),

          Expanded(
            child: Stack(children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  // Info cards row
                  Row(children: [
                    Expanded(child: _infoCard(Icons.email_outlined, lang.isRTL ? 'البريد' : 'Email', 'support@agrilens.app')),
                    const SizedBox(width: 8),
                    Expanded(child: _infoCard(Icons.phone_outlined, lang.isRTL ? 'الهاتف' : 'Phone', '+20 123 456 789')),
                    const SizedBox(width: 8),
                    Expanded(child: _infoCard(Icons.access_time, lang.isRTL ? 'ساعات العمل' : 'Hours', '9AM – 6PM')),
                  ]),
                  const SizedBox(height: 20),

                  // Contact form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(lang.isRTL ? 'إرسال رسالة' : 'Send a Message',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                        const SizedBox(height: 16),
                        _fieldLabel(lang.isRTL ? 'الاسم' : 'Name'),
                        const SizedBox(height: 8),
                        TextFormField(controller: _nameCtrl, decoration: _inputDec(), style: const TextStyle(fontSize: 15),
                            validator: (v) => (v == null || v.isEmpty) ? '' : null),
                        const SizedBox(height: 16),
                        _fieldLabel(lang.isRTL ? 'البريد الإلكتروني' : 'Email'),
                        const SizedBox(height: 8),
                        TextFormField(controller: _emailCtrl, decoration: _inputDec(), keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 15), validator: (v) => (v == null || v.isEmpty) ? '' : null),
                        const SizedBox(height: 16),
                        _fieldLabel(lang.isRTL ? 'الموضوع' : 'Subject'),
                        const SizedBox(height: 8),
                        TextFormField(controller: _subjectCtrl, decoration: _inputDec(), style: const TextStyle(fontSize: 15),
                            validator: (v) => (v == null || v.isEmpty) ? '' : null),
                        const SizedBox(height: 16),
                        _fieldLabel(lang.isRTL ? 'الرسالة' : 'Message'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _messageCtrl,
                          maxLines: 5,
                          decoration: _inputDec(hint: lang.isRTL ? 'اكتب رسالتك هنا...' : 'Describe your issue...'),
                          style: const TextStyle(fontSize: 15),
                          validator: (v) => (v == null || v.isEmpty) ? '' : null,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.send, size: 18),
                            label: Text(lang.isRTL ? 'إرسال' : 'Submit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // FAQ link
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(children: [
                      Text(lang.isRTL ? 'تحقق من الأسئلة الشائعة أولاً' : 'Check our FAQ first',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                      const SizedBox(height: 8),
                      Text(lang.isRTL ? 'قد تجد إجابتك بشكل أسرع' : 'You might find the answer faster',
                          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => context.push('/faq'),
                        child: Text(
                          lang.isRTL ? 'عرض الأسئلة الشائعة ←' : 'View Frequently Asked Questions →',
                          style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),

              // Success overlay
              if (_showSuccess)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Container(
                      width: 300,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 64, height: 64,
                          decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                          child: const Icon(Icons.check, size: 32, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(lang.isRTL ? 'تم الإرسال!' : 'Message Sent!',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                        const SizedBox(height: 8),
                        Text(lang.isRTL ? 'سنرد عليك خلال 24 ساعة' : "We'll respond within 24 hours",
                            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 11, color: AppColors.primary), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _fieldLabel(String label) => Text(label,
      style: const TextStyle(color: Color(0xFF374151), fontSize: 15, fontWeight: FontWeight.w500));

  InputDecoration _inputDec({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.transparent)),
  );
}
