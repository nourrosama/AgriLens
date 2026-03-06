import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

class FieldOverviewScreen extends StatelessWidget {
  final String fieldId;
  const FieldOverviewScreen({super.key, required this.fieldId});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(context, lang),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  _fieldInfo(lang),
                  const SizedBox(height: 24),
                  _heatmap(lang),
                  const SizedBox(height: 24),
                  _healthTrend(lang),
                  const SizedBox(height: 24),
                  _diseaseHistory(lang),
                  const SizedBox(height: 24),
                  _currentConditions(lang),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, LanguageProvider lang) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.go('/fields'),
          child: Padding(padding: const EdgeInsets.all(8),
              child: Transform.flip(flipX: lang.isRTL, child: const Icon(Icons.arrow_back, size: 28, color: AppColors.textSecondary))),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(lang.isRTL ? 'نظرة عامة - الحقل أ' : 'Field A Overview',
            style: const TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w600))),
        GestureDetector(
          onTap: () => context.push('/edit-field/$fieldId'),
          child: Row(children: [
            const Icon(Icons.edit, size: 24, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(lang.t('common.edit'), style: const TextStyle(color: AppColors.primary, fontSize: 16)),
          ]),
        ),
      ]),
    );
  }

  Widget _fieldInfo(LanguageProvider lang) {
    return _card(Column(children: [
      Row(children: [
        const Icon(Icons.location_on, size: 24, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(lang.isRTL ? 'القسم الشمالي • 2.5 فدان' : 'North Section • 2.5 feddan',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _miniStat(lang.t('fields.health'), '92${lang.t('units.percent')}', AppColors.primary)),
        const SizedBox(width: 16),
        Expanded(child: _miniStat(lang.t('fields.riskLevel'), lang.t('forecast.lowRisk'), const Color(0xFFFFC107))),
        const SizedBox(width: 16),
        Expanded(child: _miniStat(lang.t('home.alerts'), '0', AppColors.primaryDark)),
      ]),
    ]));
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _heatmap(LanguageProvider lang) {
    final rng = Random(42);
    final colors = [AppColors.primary, const Color(0xFF8BC34A), const Color(0xFFFFC107), const Color(0xFFFF9800)];
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(lang.isRTL ? 'خريطة حرارية للأمراض' : 'Disease Heatmap',
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 5, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8, crossAxisSpacing: 8,
        children: List.generate(25, (i) => Container(
          decoration: BoxDecoration(
            color: rng.nextDouble() > 0.8 ? colors[2] : colors[rng.nextInt(2)],
            borderRadius: BorderRadius.circular(4),
          ),
        )),
      ),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(lang.t('forecast.lowRisk'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        Row(children: [
          for (final c in [AppColors.primary, const Color(0xFF8BC34A), const Color(0xFFFFC107), const Color(0xFFFF9800), const Color(0xFFF44336)])
            Container(width: 24, height: 12, margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
        ]),
        Text(lang.t('forecast.highRisk'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ]),
    ]));
  }

  Widget _healthTrend(LanguageProvider lang) {
    final data = [85, 82, 78, 75, 72, 70, 68];
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(lang.isRTL ? 'اتجاه الصحة لـ 7 أيام' : '7-Day Health Trend',
            style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
        const Icon(Icons.trending_down, color: Color(0xFFFFC107), size: 24),
      ]),
      const SizedBox(height: 16),
      SizedBox(
        height: 160,
        child: CustomPaint(
          size: const Size(double.infinity, 160),
          painter: _LinePainter(data, const Color(0xFFFFC107)),
        ),
      ),
      const SizedBox(height: 8),
      Text(lang.isRTL ? 'الصحة في انخفاض - راقب عن كثب' : 'Health declining - monitor closely',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
    ]));
  }

  Widget _diseaseHistory(LanguageProvider lang) {
    final data = [2, 1, 3, 4, 2, 5];
    final months = lang.isRTL ? ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو'] : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(lang.isRTL ? 'تاريخ الأمراض (6 أشهر)' : 'Disease History (6 Months)',
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      SizedBox(
        height: 160,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (int i = 0; i < data.length; i++) ...[
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Container(
                height: data[i] * 24.0,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              Text(months[i], style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            ])),
            if (i < data.length - 1) const SizedBox(width: 8),
          ],
        ]),
      ),
    ]));
  }

  Widget _currentConditions(LanguageProvider lang) {
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(lang.isRTL ? 'الظروف الحالية' : 'Current Conditions',
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _conditionItem(Icons.thermostat, lang.t('home.temp'), '28${lang.t('units.celsius')}')),
        Expanded(child: _conditionItem(Icons.water_drop, lang.t('home.humidity'), '65${lang.t('units.percent')}')),
        Expanded(child: _conditionItem(Icons.air, lang.t('home.wind'), '12 ${lang.t('units.kmh')}')),
      ]),
    ]));
  }

  Widget _conditionItem(IconData icon, String label, String value) {
    return Column(children: [
      Icon(icon, size: 28, color: AppColors.primary),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: AppColors.primaryDark, fontSize: 16)),
    ]);
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<int> data;
  final Color color;
  _LinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()..color = color..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
    final maxVal = data.reduce(max).toDouble();
    final minVal = data.reduce(min).toDouble();
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i * size.width / (data.length - 1);
      final y = size.height - ((data[i] - minVal) / range) * size.height * 0.8 - size.height * 0.1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
