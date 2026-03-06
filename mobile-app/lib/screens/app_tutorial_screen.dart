import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

/// App Tutorial screen — matches TSX AppTutorial.tsx exactly.
/// Step-by-step tutorial with progress indicator, step detail card, grid overview.
class AppTutorialScreen extends StatefulWidget {
  const AppTutorialScreen({super.key});

  @override
  State<AppTutorialScreen> createState() => _AppTutorialScreenState();
}

class _AppTutorialScreenState extends State<AppTutorialScreen> {
  int _activeStep = 0;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    final steps = [
      (Icons.camera_alt_outlined, '📸', lang.isRTL ? 'التقاط صور النباتات' : 'Capture Plant Photos',
       lang.isRTL ? 'التقط صورة واضحة للجزء المتضرر من النبات. حاول الحصول على إضاءة جيدة لنتائج أدق.' : 'Take a clear photo of the affected plant part. Try to get good lighting for more accurate results.',
       const Color(0xFFDCFCE7), AppColors.primary),
      (Icons.check_circle_outline, '✅', lang.isRTL ? 'مراجعة نتائج التشخيص' : 'Review Diagnosis Results',
       lang.isRTL ? 'اطلع على نتائج الكشف عن الأمراض مع نسبة الثقة والتوصيات العلاجية المقترحة.' : 'Review the disease detection results with confidence scores and recommended treatment options.',
       const Color(0xFFDBEAFE), const Color(0xFF2563EB)),
      (Icons.location_on_outlined, '🌾', lang.isRTL ? 'إدارة حقولك' : 'Manage Your Fields',
       lang.isRTL ? 'أضف حقولك الزراعية وتتبع صحة كل حقل بشكل منفصل للحصول على رؤية شاملة.' : 'Add your agricultural fields and track each field\'s health separately for comprehensive oversight.',
       const Color(0xFFF3E8FF), const Color(0xFF7C3AED)),
      (Icons.cloud_outlined, '🌤️', lang.isRTL ? 'متابعة توقعات الطقس' : 'Follow Weather Forecasts',
       lang.isRTL ? 'تتبع توقعات الطقس وتأثيرها على مخاطر الأمراض لاتخاذ إجراءات وقائية مبكرة.' : 'Track weather forecasts and their impact on disease risks to take early preventive measures.',
       const Color(0xFFFEF3C7), const Color(0xFFD97706)),
      (Icons.bar_chart_outlined, '📊', lang.isRTL ? 'تحليل التقارير' : 'Analyze Reports',
       lang.isRTL ? 'راجع التقارير التفصيلية لتاريخ الفحوصات وإحصاءات صحة الحقول والاتجاهات الزمنية.' : 'Review detailed reports of scan history, field health statistics, and trends over time.',
       const Color(0xFFFCE7F3), const Color(0xFFDB2777)),
      (Icons.chat_outlined, '🤖', lang.isRTL ? 'استشر المساعد الذكي' : 'Consult AI Assistant',
       lang.isRTL ? 'تحدث مع مساعد AgriLens الذكي للحصول على نصائح مخصصة ومجاوبة لاستفساراتك الزراعية.' : 'Chat with AgriLens AI assistant for personalized advice and answers to your agricultural questions.',
       const Color(0xFFCCFBF1), const Color(0xFF0D9488)),
    ];

    final current = steps[_activeStep];

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
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
                Text(lang.isRTL ? 'دليل التطبيق' : 'App Tutorial',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                Text(lang.isRTL ? 'تعلم كيفية استخدام AgriLens' : 'Learn how to use AgriLens',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              ]),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Welcome card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(children: [
                    const Text('🌱', style: TextStyle(fontSize: 48)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Welcome to AgriLens!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      const SizedBox(height: 4),
                      Text(lang.isRTL ? 'اتبع هذه الخطوات للاستفادة القصوى من التطبيق!' : "Follow these steps to get the most out of your farming assistant!",
                          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                    ])),
                  ]),
                ),
                const SizedBox(height: 20),

                // Progress dots
                Row(children: List.generate(steps.length, (i) {
                  final isActive = i == _activeStep;
                  final isDone = i < _activeStep;
                  return Expanded(child: Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeStep = i),
                        child: Column(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? AppColors.primary : isDone ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB),
                            ),
                            child: Center(child: Text('${i + 1}', style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: isActive ? Colors.white : isDone ? AppColors.primary : const Color(0xFF9CA3AF),
                            ))),
                          ),
                        ]),
                      ),
                    ),
                    if (i < steps.length - 1)
                      Expanded(child: Container(height: 4, decoration: BoxDecoration(
                        color: isDone ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ))),
                  ]));
                })),
                const SizedBox(height: 20),

                // Active step card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [current.$5.withValues(alpha: 0.5), current.$5]),
                        shape: BoxShape.circle,
                      ),
                      child: Text(current.$2, style: const TextStyle(fontSize: 48)),
                    ),
                    const SizedBox(height: 16),
                    Text(current.$3, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                    const SizedBox(height: 12),
                    Text(current.$4, style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280), height: 1.6), textAlign: TextAlign.center),
                    const SizedBox(height: 24),

                    // Navigation buttons
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (_activeStep > 0) ...[
                        OutlinedButton(
                          onPressed: () => setState(() => _activeStep--),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
                          child: Text(lang.t('common.back')),
                        ),
                        const SizedBox(width: 12),
                      ],
                      ElevatedButton(
                        onPressed: _activeStep < steps.length - 1
                            ? () => setState(() => _activeStep++)
                            : () => context.go('/home'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                        ),
                        child: Text(_activeStep < steps.length - 1
                            ? lang.t('common.next')
                            : (lang.isRTL ? 'انتهى' : 'Done')),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // Steps grid
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(steps.length, (i) {
                    final s = steps[i];
                    final isActive = i == _activeStep;
                    return GestureDetector(
                      onTap: () => setState(() => _activeStep = i),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isActive ? AppColors.primary : AppColors.border, width: isActive ? 2 : 1),
                          boxShadow: isActive ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 8)] : null,
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: s.$5, borderRadius: BorderRadius.circular(8)),
                            child: Icon(s.$1, size: 16, color: s.$6)),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.$3, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(s.$4, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          ])),
                        ]),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Action buttons
                Row(children: [
                  Expanded(child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(children: [
                      Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow, size: 20, color: Color(0xFFDC2626))),
                      const SizedBox(height: 8),
                      Text(lang.isRTL ? 'مشاهدة الفيديو' : 'Watch Video', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
                      Text(lang.isRTL ? '5 دقائق' : '5 min tutorial', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    ]),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _activeStep = 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: Column(children: [
                        Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                          child: const Icon(Icons.replay, size: 20, color: AppColors.primary)),
                        const SizedBox(height: 8),
                        Text(lang.isRTL ? 'إعادة التشغيل' : 'Restart', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
                        Text(lang.isRTL ? 'من البداية' : 'Start from beginning', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                      ]),
                    ),
                  )),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
