import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    final sections = [
      (lang.isRTL ? 'قبول الشروط' : 'Acceptance of Terms',
       lang.isRTL ? 'باستخدام تطبيق AgriLens، فإنك توافق على الالتزام بهذه الشروط والأحكام.' : 'By using AgriLens, you agree to be bound by these terms and conditions.'),
      (lang.isRTL ? 'استخدام الخدمة' : 'Use of Service',
       lang.isRTL ? 'يُتاح التطبيق للمزارعين وعشاق الزراعة فقط. يُحظر استخدامه لأغراض غير قانونية.' : 'The app is available to farmers and agriculture enthusiasts. Use for illegal purposes is prohibited.'),
      (lang.isRTL ? 'حقوق الملكية الفكرية' : 'Intellectual Property',
       lang.isRTL ? 'جميع المحتويات وتقنيات الذكاء الاصطناعي وتصميمات التطبيق هي ملك حصري لـ AgriLens.' : 'All content, AI technology, and app designs are the exclusive property of AgriLens.'),
      (lang.isRTL ? 'دقة البيانات' : 'Data Accuracy',
       lang.isRTL ? 'نسعى لتوفير تشخيصات دقيقة، لكن لا نضمن دقة 100% في جميع الحالات. يُوصى باستشارة خبراء زراعيين.' : 'We strive to provide accurate diagnostics, but cannot guarantee 100% accuracy. Consulting agricultural experts is recommended.'),
      (lang.isRTL ? 'تحديد المسؤولية' : 'Limitation of Liability',
       lang.isRTL ? 'لن تتحمل AgriLens مسؤولية أي خسائر مالية ناتجة عن استخدام التوصيات المقدمة في التطبيق.' : 'AgriLens shall not be liable for any financial losses resulting from using recommendations provided in the app.'),
      (lang.isRTL ? 'التغييرات على الشروط' : 'Changes to Terms',
       lang.isRTL ? 'نحتفظ بحق تعديل هذه الشروط في أي وقت. سيتم إخطارك بأي تغييرات جوهرية.' : 'We reserve the right to modify these terms at any time. You will be notified of any material changes.'),
    ];

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
                Text(lang.isRTL ? 'الشروط والأحكام' : 'Terms & Conditions',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                Text(lang.isRTL ? 'آخر تحديث: يناير 2025' : 'Last updated: January 2025',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              ]),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Intro card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBBF7D0))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                      child: const Icon(Icons.description_outlined, size: 24, color: AppColors.primary)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Welcome to AgriLens', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                      const SizedBox(height: 6),
                      const Text('Please read these terms and conditions carefully before using our application. By using AgriLens, you agree to be bound by these terms.',
                          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 16),

                // Section cards
                ...sections.map((s) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                    const SizedBox(height: 10),
                    Text(s.$2, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.6)),
                  ]),
                )),

                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    const Text('For questions about these terms, please contact us at', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    const SizedBox(height: 4),
                    Text('legal@agrilens.app', style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
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
