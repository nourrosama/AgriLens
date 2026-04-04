import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/api_client.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/widgets/bottom_nav.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ApiClient _apiClient = ApiClient();
  Map<String, dynamic>? _report;
  String? _filename;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _apiClient.get(
        '/api/reports/export',
        auth: true,
        query: {'period': 'weekly', 'format': 'json'},
      );
      final data = response['data'] as Map<String, dynamic>;
      setState(() {
        _report = data['report'] as Map<String, dynamic>;
        _filename = data['filename']?.toString();
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

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
                    onTap: () => context.go('/home'),
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
                      lang.t('reports.title'),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _loadReport,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _error != null
                  ? _errorState(lang)
                  : RefreshIndicator(
                      onRefresh: _loadReport,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _summaryCards(lang),
                            const SizedBox(height: 24),
                            _weeklyScansChart(lang),
                            const SizedBox(height: 24),
                            _diseaseBreakdown(lang),
                            const SizedBox(height: 24),
                            _exportCard(lang),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(active: 'reports'),
    );
  }

  Widget _errorState(LanguageProvider lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 42, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              lang.isRTL ? 'تعذر إنشاء التقرير' : 'Unable to generate report',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReport,
              child: Text(lang.t('reports.generate')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCards(LanguageProvider lang) {
    final summary = (_report?['summary'] as Map<String, dynamic>? ?? const {});
    final items = <({String label, String value, Color color})>[
      (
        label: lang.isRTL ? 'إجمالي الفحوصات' : 'Total scans',
        value: '${summary['total_scans'] ?? 0}',
        color: AppColors.primary,
      ),
      (
        label: lang.t('fields.totalFields'),
        value: '${summary['total_fields'] ?? 0}',
        color: AppColors.primaryDark,
      ),
      (
        label: lang.t('fields.avgHealth'),
        value:
            '${summary['average_health_score'] ?? 0}${lang.t('units.percent')}',
        color: AppColors.primary,
      ),
      (
        label: lang.t('fields.alerts'),
        value: '${summary['active_alerts'] ?? 0}',
        color: const Color(0xFFFFC107),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.15,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.value,
                    style: TextStyle(
                      color: item.color,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _weeklyScansChart(LanguageProvider lang) {
    final scans = ((_report?['scans'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>());
    final counts = List<int>.filled(7, 0);
    final today = DateTime.now();
    for (final scan in scans) {
      final createdAt = DateTime.tryParse(scan['created_at']?.toString() ?? '');
      if (createdAt == null) {
        continue;
      }
      final diff = today.difference(createdAt).inDays;
      if (diff >= 0 && diff < 7) {
        counts[6 - diff] += 1;
      }
    }
    final days = lang.isRTL
        ? ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.isRTL ? 'فحوصات هذا الأسبوع' : 'Scans this week',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int index = 0; index < counts.length; index++) ...[
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: max(8, counts[index] * 18).toDouble(),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          days[index],
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index < counts.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diseaseBreakdown(LanguageProvider lang) {
    final scans = ((_report?['scans'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>());
    final counts = <String, int>{};
    for (final scan in scans) {
      final detection =
          (scan['detection_result'] as Map<String, dynamic>?) ?? const {};
      final disease = detection['disease']?.toString() ?? 'Healthy';
      counts[disease] = (counts[disease] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.isRTL ? 'توزيع النتائج' : 'Result breakdown',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Text(
              lang.isRTL ? 'لا توجد نتائج بعد.' : 'No scan results yet.',
              style: const TextStyle(color: AppColors.textSecondary),
            )
          else
            ...entries
                .take(5)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _exportCard(LanguageProvider lang) {
    final generatedAt = _report?['generated_at']?.toString() ?? '';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('reports.generate'),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _filename ??
                (lang.isRTL
                    ? 'لم يتم تجهيز ملف بعد'
                    : 'No export prepared yet'),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (generatedAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              generatedAt,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.download_rounded),
              label: Text(lang.t('reports.download')),
            ),
          ),
        ],
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
}
