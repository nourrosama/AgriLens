import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

class DataPrivacyScreen extends StatelessWidget {
  const DataPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    final sections = [
      (Icons.remove_red_eye_outlined, lang.isRTL ? 'ما نجمعه' : 'What We Collect',
       lang.isRTL ? 'نجمع ما تدخله من بيانات المزرعة والحقول وصور النباتات والموقع الجغرافي لتوفير تشخيصات دقيقة.' : 'We collect the farm data you enter, field details, plant photos, and location data to provide accurate diagnostics.'),
      (Icons.download_outlined, lang.isRTL ? 'كيف نستخدم بياناتك' : 'How We Use Your Data',
       lang.isRTL ? 'تُستخدم بياناتك لتحسين خوارزميات الكشف عن الأمراض وتقديم توصيات مخصصة لمزرعتك.' : 'Your data is used to improve our disease detection algorithms and provide personalized recommendations for your farm.'),
      (Icons.lock_outline, lang.isRTL ? 'حماية البيانات' : 'Data Protection',
       lang.isRTL ? 'نستخدم تشفير من الدرجة العسكرية (AES-256) لحماية جميع بياناتك المخزنة والمنقولة.' : 'We use military-grade encryption (AES-256) to protect all your stored and transmitted data.'),
      (Icons.shield_outlined, lang.isRTL ? 'أمان الحساب' : 'Account Security',
       lang.isRTL ? 'نوصي بتفعيل التحقق الثنائي وعدم مشاركة بيانات تسجيل الدخول مع أي شخص.' : 'We recommend enabling two-factor authentication and never sharing your login details.'),
      (Icons.share_outlined, lang.isRTL ? 'مشاركة البيانات' : 'Data Sharing',
       lang.isRTL ? 'لن نبيع بياناتك لطرف ثالث. قد نشارك بيانات مجهولة الهوية لأغراض بحثية فقط.' : "We will never sell your data to third parties. We may share anonymized data for research purposes only."),
      (Icons.email_outlined, lang.isRTL ? 'الاتصال بنا' : 'Contact Us',
       lang.isRTL ? 'إذا كان لديك أي استفسارات حول الخصوصية، تواصل معنا على privacy@agrilens.app' : 'If you have any privacy inquiries, contact us at privacy@agrilens.app'),
    ];

    final dataRights = lang.isRTL
        ? ['عرض جميع البيانات المتعلقة بك', 'تصدير بياناتك بصيغة قابلة للقراءة', 'حذف حسابك وجميع البيانات المرتبطة', 'إلغاء الاشتراك في جمع بيانات التحليل']
        : ['View all data we have about you', 'Export your data in a readable format', 'Delete your account and all associated data', 'Opt-out of data collection for analytics'];

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
                child: Container(padding: const EdgeInsets.all(8),
                  child: Transform.flip(flipX: lang.isRTL, child: const Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary))),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lang.isRTL ? 'سياسة الخصوصية' : 'Data Privacy',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                Text(lang.isRTL ? 'كيف نحمي بياناتك' : 'How we protect your data',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              ]),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Intro
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBBF7D0))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                      child: const Icon(Icons.shield, size: 24, color: AppColors.primary)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Your Privacy Matters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                      const SizedBox(height: 6),
                      const Text('At AgriLens, we take your privacy seriously. This policy explains how we collect, use, and protect your personal information.',
                          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 16),

                // Sections
                ...sections.map((s) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                      child: Icon(s.$1, size: 20, color: AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      const SizedBox(height: 8),
                      Text(s.$3, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5)),
                    ])),
                  ]),
                )),

                // Data rights
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Manage Your Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                    const SizedBox(height: 8),
                    const Text('You have full control over your data. You can request to:', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                    const SizedBox(height: 12),
                    ...dataRights.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(r, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)))),
                      ]),
                    )),
                  ]),
                ),
                const SizedBox(height: 12),

                // Contact footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Text(lang.isRTL ? 'للاستفسارات المتعلقة بالخصوصية' : 'For privacy concerns or data requests',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    const SizedBox(height: 4),
                    const Text('privacy@agrilens.app', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
