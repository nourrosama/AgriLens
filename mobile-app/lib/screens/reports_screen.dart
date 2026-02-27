import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/widgets/bottom_nav.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(children: [
              GestureDetector(onTap: () => context.go('/home'),
                child: Padding(padding: const EdgeInsets.all(8),
                    child: Transform.flip(flipX: lang.isRTL, child: const Icon(Icons.arrow_back, size: 28, color: AppColors.textSecondary)))),
              const SizedBox(width: 16),
              Expanded(child: Text(lang.t('reports.title'), style: const TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w600))),
              const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.download_rounded, size: 28, color: AppColors.primary)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                _periodSelector(lang),
                const SizedBox(height: 24),
                _summaryCards(lang),
                const SizedBox(height: 24),
                _weeklyScansChart(lang),
                const SizedBox(height: 24),
                _healthTrend(lang),
                const SizedBox(height: 24),
                _diseaseBreakdown(lang),
                const SizedBox(height: 24),
                _exportOptions(lang),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: const BottomNav(active: 'reports'),
    );
  }

  Widget _periodSelector(LanguageProvider lang) {
    return Row(children: [
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
        child: Center(child: Text(lang.isRTL ? 'أسبوعي' : 'Weekly', style: const TextStyle(color: Colors.white, fontSize: 16))),
      )),
      const SizedBox(width: 12),
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Center(child: Text(lang.isRTL ? 'شهري' : 'Monthly', style: const TextStyle(color: AppColors.textSecondary, fontSize: 16))),
      )),
      const SizedBox(width: 12),
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Center(child: Text(lang.isRTL ? 'سنوي' : 'Yearly', style: const TextStyle(color: AppColors.textSecondary, fontSize: 16))),
      )),
    ]);
  }

  Widget _summaryCards(LanguageProvider lang) {
    final items = [
      [lang.isRTL ? 'إجمالي الفحوصات' : 'Total Scans', '70', lang.isRTL ? '+12٪ من الأسبوع الماضي' : '+12% from last week', AppColors.primary],
      [lang.isRTL ? 'أمراض مكتشفة' : 'Diseases Found', '8', lang.isRTL ? '3 حالات نشطة' : '3 active cases', const Color(0xFFFFC107)],
      [lang.t('fields.avgHealth'), '83${lang.t('units.percent')}', lang.isRTL ? 'حالة جيدة' : 'Good condition', AppColors.primary],
      [lang.isRTL ? 'التنبيهات المرسلة' : 'Alerts Sent', '12', lang.isRTL ? 'هذا الأسبوع' : 'This week', AppColors.textSecondary],
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.3,
      children: items.map((i) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(i[0] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 4),
          Text(i[1] as String, style: const TextStyle(color: AppColors.primaryDark, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(i[2] as String, style: TextStyle(color: i[3] as Color, fontSize: 12)),
        ]),
      )).toList(),
    );
  }

  Widget _weeklyScansChart(LanguageProvider lang) {
    final data = [12, 8, 15, 10, 14, 6, 5];
    final days = lang.isRTL ? ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'] : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(lang.isRTL ? 'الفحوصات هذا الأسبوع' : 'Scans This Week',
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      SizedBox(height: 160, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (int i = 0; i < data.length; i++) ...[
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(height: data[i] * 8.0, decoration: BoxDecoration(color: AppColors.primary, borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))),
            const SizedBox(height: 8),
            Text(days[i], style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
          ])),
          if (i < data.length - 1) const SizedBox(width: 4),
        ],
      ])),
    ]));
  }

  Widget _healthTrend(LanguageProvider lang) {
    final data = [85, 88, 82, 79, 83, 86];
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(lang.isRTL ? 'اتجاه الصحة لمدة 6 أشهر' : '6-Month Health Trend',
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      SizedBox(height: 160, child: CustomPaint(size: const Size(double.infinity, 160), painter: _LinePainter(data, AppColors.primary))),
    ]));
  }

  Widget _diseaseBreakdown(LanguageProvider lang) {
    final diseases = [
      [lang.isRTL ? 'اللفحة المتأخرة' : 'Late Blight', 45, const Color(0xFFF44336)],
      [lang.isRTL ? 'اللفحة المبكرة' : 'Early Blight', 30, const Color(0xFFFFC107)],
      [lang.isRTL ? 'بقع الأوراق' : 'Leaf Spot', 15, const Color(0xFFFF9800)],
      [lang.isRTL ? 'أخرى' : 'Other', 10, AppColors.primary],
    ];
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(lang.isRTL ? 'توزيع الأمراض' : 'Disease Breakdown',
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      // Donut mockup
      Center(
        child: SizedBox(
          width: 160, height: 160,
          child: CustomPaint(painter: _DonutPainter(diseases.map((d) => [d[1] as int, d[2] as Color]).toList())),
        ),
      ),
      const SizedBox(height: 16),
      ...diseases.map((d) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: d[2] as Color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(d[0] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ]),
          Text('${d[1]}${lang.t('units.percent')}', style: const TextStyle(color: AppColors.primaryDark, fontSize: 14)),
        ]),
      )),
    ]));
  }

  Widget _exportOptions(LanguageProvider lang) {
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(lang.isRTL ? 'تصدير التقرير' : 'Export Report',
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      _exportBtn(lang.isRTL ? 'تصدير PDF' : 'Export as PDF'),
      const SizedBox(height: 12),
      _exportBtn(lang.isRTL ? 'تصدير CSV' : 'Export as CSV'),
    ]));
  }

  Widget _exportBtn(String label) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.calendar_today, size: 24, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
      ]),
    );
  }

  Widget _card(Widget child) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: child);
  }
}

class _LinePainter extends CustomPainter {
  final List<int> data; final Color color;
  _LinePainter(this.data, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()..color = color..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
    final maxVal = data.reduce(max).toDouble(); final minVal = data.reduce(min).toDouble();
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i * size.width / (data.length - 1);
      final y = size.height - ((data[i] - minVal) / range) * size.height * 0.8 - size.height * 0.1;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

class _DonutPainter extends CustomPainter {
  final List<List<dynamic>> data;
  _DonutPainter(this.data);
  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold<int>(0, (s, d) => s + (d[0] as int));
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    double startAngle = -pi / 2;
    for (final d in data) {
      final sweep = 2 * pi * (d[0] as int) / total;
      final paint = Paint()..color = d[1] as Color..style = PaintingStyle.stroke..strokeWidth = 20..strokeCap = StrokeCap.butt;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 10), startAngle, sweep - 0.05, false, paint);
      startAngle += sweep;
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}
