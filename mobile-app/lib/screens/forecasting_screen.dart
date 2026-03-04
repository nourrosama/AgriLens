import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/widgets/bottom_nav.dart';
import 'package:agrilens/widgets/chatbot_button.dart';

class ForecastingScreen extends StatelessWidget {
  const ForecastingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(children: [
                GestureDetector(onTap: () => context.go('/home'),
                  child: Padding(padding: const EdgeInsets.all(8),
                      child: Transform.flip(flipX: lang.isRTL, child: const Icon(Icons.arrow_back, size: 28, color: AppColors.textSecondary)))),
                const SizedBox(width: 16),
                Text(lang.t('forecast.title'), style: const TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w600)),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  _currentRisk(lang),
                  const SizedBox(height: 24),
                  _riskTrend(lang),
                  const SizedBox(height: 24),
                  _peakAlert(lang),
                  const SizedBox(height: 24),
                  _recommendations(lang),
                  const SizedBox(height: 24),
                  _factors(lang),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ]),
          const ChatbotButton(),
        ]),
      ),
      bottomNavigationBar: const BottomNav(active: 'home'),
    );
  }

  Widget _currentRisk(LanguageProvider lang) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(lang.t('forecast.currentRisk'), style: const TextStyle(color: Colors.white, fontSize: 18)),
          const Icon(Icons.trending_up, color: Colors.white, size: 28),
        ]),
        const SizedBox(height: 8),
        Text(lang.t('forecast.lowRisk'), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(lang.isRTL ? 'ظروف مواتية لمحاصيل صحية' : 'Favorable conditions for healthy crops',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16)),
      ]),
    );
  }

  Widget _riskTrend(LanguageProvider lang) {
    final data = [25, 30, 45, 65, 55, 40, 35];
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(lang.t('forecast.riskTrend'), style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      SizedBox(height: 200, child: CustomPaint(size: const Size(double.infinity, 200), painter: _AreaPainter(data))),
      const SizedBox(height: 16),
      Wrap(spacing: 16, runSpacing: 8, children: [
        _legendDot(AppColors.primary, '${lang.t('forecast.lowRisk')} (0-30${lang.t('units.percent')})'),
        _legendDot(const Color(0xFFFFC107), '${lang.t('forecast.moderateRisk')} (31-60${lang.t('units.percent')})'),
        _legendDot(const Color(0xFFF44336), '${lang.t('forecast.highRisk')} (61-100${lang.t('units.percent')})'),
      ]),
    ]));
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    ]);
  }

  Widget _peakAlert(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_rounded, color: Color(0xFFFFC107), size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lang.isRTL ? 'ذروة الخطر: الخميس' : 'Peak Risk: Thursday',
              style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(lang.isRTL ? 'سيزداد خطر المرض إلى مستويات متوسطة بسبب الأمطار المتوقعة والرطوبة العالية.' : 'Disease risk will increase to moderate levels due to expected rainfall and high humidity.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.cloud, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(lang.isRTL ? 'احتمال المطر 80٪' : '80% chance of rain', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.water_drop, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text('${lang.t('home.humidity')}: 85${lang.t('units.percent')}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ]),
        ])),
      ]),
    );
  }

  Widget _recommendations(LanguageProvider lang) {
    final steps = lang.isRTL
        ? [['مراقبة دقيقة', 'افحص الحقول يومياً لأعراض الأمراض المبكرة'],
           ['علاج وقائي', 'فكر في استخدام مبيد فطري قبل الخميس'],
           ['تحسين الصرف', 'تأكد من صرف المياه بشكل صحيح في جميع الحقول']]
        : [['Monitor Closely', 'Inspect fields daily for early disease symptoms'],
           ['Preventive Treatment', 'Consider applying fungicide before Thursday'],
           ['Improve Drainage', 'Ensure proper water drainage in all fields']];
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(lang.t('disease.recommendedAction'), style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      ...steps.asMap().entries.map((e) => Container(
        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 28, height: 28, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 14)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.value[0], style: const TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(e.value[1], style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ])),
        ]),
      )),
    ]));
  }

  Widget _factors(LanguageProvider lang) {
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(lang.isRTL ? 'العوامل المساهمة' : 'Contributing Factors',
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      _factorBar(lang.isRTL ? 'درجة الحرارة' : 'Temperature', lang.isRTL ? 'مثالية' : 'Optimal', 0.7, AppColors.primary),
      const SizedBox(height: 16),
      _factorBar(lang.t('home.humidity'), lang.t('disease.medium'), 0.65, const Color(0xFFFFC107)),
      const SizedBox(height: 16),
      _factorBar(lang.isRTL ? 'الأمطار' : 'Rainfall', lang.t('disease.low'), 0.3, AppColors.primary),
    ]));
  }

  Widget _factorBar(String label, String status, double value, Color color) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        Text(status, style: TextStyle(color: color, fontSize: 16)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: AppColors.background, valueColor: AlwaysStoppedAnimation(color))),
    ]);
  }

  Widget _card(Widget child) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: child);
  }
}

class _AreaPainter extends CustomPainter {
  final List<int> data;
  _AreaPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()..color = const Color(0xFFFFC107)..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xCCFFC107), Color(0x1AFFC107)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i * size.width / (data.length - 1);
      final y = size.height - (data[i] / 100) * size.height;
      if (i == 0) { path.moveTo(x, y); fillPath.moveTo(x, size.height); fillPath.lineTo(x, y); }
      else { path.lineTo(x, y); fillPath.lineTo(x, y); }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
