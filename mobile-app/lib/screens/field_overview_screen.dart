import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/fields_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/weather_provider.dart';

class FieldOverviewScreen extends StatelessWidget {
  const FieldOverviewScreen({super.key, required this.fieldId});

  final String fieldId;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final fieldsProvider = context.watch<FieldsProvider>();
    final weatherProvider = context.watch<WeatherProvider>();
    final scanProvider = context.watch<ScanHistoryProvider>();
    final field = fieldsProvider.getField(fieldId);

    if (field == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.agriculture_outlined,
                    size: 40,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.isRTL
                        ? 'لم يتم العثور على هذا الحقل'
                        : 'Field not found',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/fields'),
                    child: Text(lang.t('common.back')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final fieldScans =
        scanProvider.scans.where((scan) => scan.fieldId == field.id).toList()
          ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    final trendPoints = _buildTrend(field.health, fieldScans);
    final riskLabel = field.status == 'healthy'
        ? lang.t('forecast.lowRisk')
        : lang.t('forecast.moderateRisk');
    final fieldWeather = field.weatherSnapshot;
    final temperature =
        (fieldWeather['temperature'] as num?)?.round() ??
        weatherProvider.temperature;
    final humidity =
        (fieldWeather['humidity'] as num?)?.round() ?? weatherProvider.humidity;
    final wind =
        (fieldWeather['wind_kmh'] as num?)?.round() ?? weatherProvider.wind;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/fields'),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Transform.flip(
                        flipX: lang.isRTL,
                        child: const Icon(
                          Icons.arrow_back,
                          size: 28,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      field.name,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/edit-field/$fieldId'),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.primary,
                    ),
                    label: Text(lang.t('common.edit')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    fieldsProvider.loadFields(),
                    scanProvider.loadScans(),
                    weatherProvider.refreshWeather(
                      farmId: field.farmId,
                      fieldId: field.id,
                    ),
                  ]);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    field.location.isEmpty
                                        ? (lang.isRTL
                                              ? 'لا يوجد موقع محدد'
                                              : 'No location set')
                                        : field.location,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _miniStat(
                                  lang.t('fields.area'),
                                  '${field.area} ${lang.t('units.feddan')}',
                                  AppColors.primaryDark,
                                ),
                                _miniStat(
                                  lang.t('fields.health'),
                                  '${field.health}${lang.t('units.percent')}',
                                  AppColors.primary,
                                ),
                                _miniStat(
                                  lang.t('fields.riskLevel'),
                                  riskLabel,
                                  field.status == 'healthy'
                                      ? AppColors.primary
                                      : const Color(0xFFFFC107),
                                ),
                                _miniStat(
                                  lang.t('fields.alerts'),
                                  '${fieldScans.where((scan) => !scan.isHealthy).length}',
                                  AppColors.primaryDark,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if ((field.cropType ?? '').isNotEmpty)
                                  _tag(
                                    '${lang.t('fields.cropType')}: ${field.cropType}',
                                  ),
                                if ((field.soilType ?? '').isNotEmpty)
                                  _tag(
                                    '${lang.t('fields.soilType')}: ${field.soilType}',
                                  ),
                                if ((field.irrigationType ?? '').isNotEmpty)
                                  _tag(
                                    '${lang.t('fields.irrigationType')}: ${field.irrigationType}',
                                  ),
                                if ((field.season ?? '').isNotEmpty)
                                  _tag('Season: ${field.season}'),
                                _tag('Farm: ${field.farmName}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.isRTL ? 'اتجاه الصحة' : 'Health Trend',
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 160,
                              child: CustomPaint(
                                size: const Size(double.infinity, 160),
                                painter: _LinePainter(
                                  trendPoints,
                                  field.status == 'healthy'
                                      ? AppColors.primary
                                      : const Color(0xFFFFC107),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              field.status == 'healthy'
                                  ? (lang.isRTL
                                        ? 'صحة الحقل مستقرة حالياً.'
                                        : 'Field health is currently stable.')
                                  : (lang.isRTL
                                        ? 'يوصى بمتابعة هذا الحقل عن قرب.'
                                        : 'This field should be monitored closely.'),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.isRTL
                                  ? 'الظروف الحالية'
                                  : 'Current Conditions',
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _conditionItem(
                                    Icons.thermostat,
                                    lang.t('home.temp'),
                                    '$temperature${lang.t('units.celsius')}',
                                  ),
                                ),
                                Expanded(
                                  child: _conditionItem(
                                    Icons.water_drop,
                                    lang.t('home.humidity'),
                                    '$humidity${lang.t('units.percent')}',
                                  ),
                                ),
                                Expanded(
                                  child: _conditionItem(
                                    Icons.air,
                                    lang.t('home.wind'),
                                    '$wind ${lang.t('units.kmh')}',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  lang.t('fields.alerts'),
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.push('/scan'),
                                  child: Text(lang.t('home.quickScan')),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (fieldScans.isEmpty)
                              Text(
                                lang.isRTL
                                    ? 'لا توجد نتائج فحص محفوظة لهذا الحقل بعد.'
                                    : 'No scan results saved for this field yet.',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              )
                            else
                              ...fieldScans
                                  .take(5)
                                  .map(
                                    (scan) => Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: scan.isHealthy
                                            ? AppColors.primaryLight
                                            : const Color(0xFFFFF8E1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                scan.isHealthy
                                                    ? Icons.check_circle
                                                    : Icons
                                                          .warning_amber_rounded,
                                                color: scan.isHealthy
                                                    ? AppColors.primary
                                                    : const Color(0xFFFFC107),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  scan.isHealthy
                                                      ? lang.t('scan.healthy')
                                                      : scan.diseaseNameEn,
                                                  style: const TextStyle(
                                                    color:
                                                        AppColors.primaryDark,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${(scan.confidence * 100).round()}${lang.t('units.percent')}',
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            scan.recommendation.isEmpty
                                                ? (lang.isRTL
                                                      ? 'لا توجد توصية إضافية.'
                                                      : 'No additional recommendation.')
                                                : scan.recommendation,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _conditionItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 28, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 16),
        ),
      ],
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.primaryDark, fontSize: 12),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  List<int> _buildTrend(int baselineHealth, List<ScanResult> scans) {
    if (scans.isEmpty) {
      return <int>[
        max(0, baselineHealth - 4),
        max(0, baselineHealth - 3),
        max(0, baselineHealth - 2),
        max(0, baselineHealth - 1),
        baselineHealth,
      ];
    }
    final trend = <int>[];
    for (final scan in scans.take(5).toList().reversed) {
      final adjustment = scan.isHealthy
          ? 0
          : scan.severity == 'high'
          ? 18
          : 10;
      trend.add(max(10, baselineHealth - adjustment));
    }
    while (trend.length < 5) {
      trend.insert(0, max(0, baselineHealth - (5 - trend.length)));
    }
    return trend;
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter(this.data, this.color);

  final List<int> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final maxVal = data.reduce(max).toDouble();
    final minVal = data.reduce(min).toDouble();
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i * size.width / (data.length - 1);
      final y =
          size.height -
          ((data[i] - minVal) / range) * size.height * 0.8 -
          size.height * 0.1;
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
  bool shouldRepaint(covariant _LinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
