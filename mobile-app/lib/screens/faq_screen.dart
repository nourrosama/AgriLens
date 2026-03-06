import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

/// FAQ screen — matches TSX FAQ.tsx exactly.
/// Expandable accordion cards with a help banner at the bottom.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    final faqs = [
      (
        lang.isRTL ? 'كيف أفحص نبتتي؟' : 'How do I scan my plant?',
        lang.isRTL
            ? 'افتح الكاميرا من الشاشة الرئيسية، صوّر النبتة المريضة، وانتظر نتائج التحليل.'
            : 'Open the camera from the home screen, take a photo of the affected plant, and wait for the analysis results.',
      ),
      (
        lang.isRTL ? 'ما مدى دقة الكشف؟' : 'How accurate is the detection?',
        lang.isRTL
            ? 'يصل معدل دقة النظام إلى 94٪ بناءً على قاعدة بيانات من أكثر من 50 مليون صورة نباتية.'
            : 'Our system achieves up to 94% accuracy based on a database of 50+ million plant images.',
      ),
      (
        lang.isRTL ? 'هل يعمل التطبيق بدون إنترنت؟' : 'Does the app work offline?',
        lang.isRTL
            ? 'يتطلب التحليل اتصالاً بالإنترنت، لكن يمكنك مشاهدة بيانات حقولك دون اتصال.'
            : 'Detection requires an internet connection, but you can view your field data offline.',
      ),
      (
        lang.isRTL ? 'كيف أضيف حقلاً جديداً؟' : 'How do I add a new field?',
        lang.isRTL
            ? 'انتقل إلى قسم "حقولي" ثم اضغط على زر "+" لإضافة حقل جديد مع إدخال تفاصيله.'
            : 'Go to "My Fields" section and tap the "+" button to add a new field with its details.',
      ),
      (
        lang.isRTL ? 'كيف يعمل التنبؤ بالأمراض؟' : 'How does disease forecasting work?',
        lang.isRTL
            ? 'يستخدم النظام بيانات الطقس ونتائج الفحوصات السابقة للتنبؤ بمخاطر الأمراض المستقبلية.'
            : 'The system uses weather data and past scan results to predict future disease risks in your fields.',
      ),
      (
        lang.isRTL ? 'هل بياناتي آمنة؟' : 'Is my data secure?',
        lang.isRTL
            ? 'نعم، جميع بياناتك مشفرة ومخزنة بشكل آمن. لن نشارك معلوماتك مع أطراف ثالثة.'
            : 'Yes, all your data is encrypted and stored securely. We never share your information with third parties.',
      ),
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
                Text(lang.isRTL ? 'الأسئلة الشائعة' : 'FAQ',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                Text(lang.isRTL ? 'اعثر على إجابات لأسئلتك' : 'Find answers to common questions',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              ]),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // FAQ items
                ...faqs.map((faq) => _FaqItem(q: faq.$1, a: faq.$2)),
                const SizedBox(height: 24),

                // Help banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(children: [
                    Text(
                      lang.isRTL ? 'هل لديك أسئلة أخرى؟' : 'Still have questions?',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lang.isRTL ? 'فريق الدعم لدينا هنا للمساعدة' : 'Our support team is here to help',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.push('/contact-support'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(lang.isRTL ? 'تواصل مع الدعم' : 'Contact Support'),
                    ),
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

class _FaqItem extends StatefulWidget {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(children: [
              Expanded(
                child: Text(widget.q, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
              ),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.primary),
            ]),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(widget.a, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.6)),
          ),
      ]),
    );
  }
}
