import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/bottom_nav.dart';
import 'package:agrilens/widgets/plan_gate.dart';

class DiseaseTrendsScreen extends StatefulWidget {
  const DiseaseTrendsScreen({super.key});

  @override
  State<DiseaseTrendsScreen> createState() => _DiseaseTrendsScreenState();
}

class _DiseaseTrendsScreenState extends State<DiseaseTrendsScreen> {
  String _period = '30'; // days: '7', '30', '90'

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();
    final scanProvider = context.watch<ScanHistoryProvider>();
    final isRTL = lang.isRTL;

    if (user.plan != 'professional') {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _appBar(isRTL, context),
        bottomNavigationBar: const BottomNav(active: ''),
        body: PlanGateBody(requiredPlan: 'professional', isRTL: isRTL),
      );
    }

    final days = int.parse(_period);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recentScans = scanProvider.scans
        .where((s) => s.scannedAt.isAfter(cutoff) && s.hasDetection && !s.isHealthy)
        .toList();

    // Build frequency map: disease → count
    final Map<String, int> freq = {};
    for (final s in recentScans) {
      freq[s.diseaseNameEn] = (freq[s.diseaseNameEn] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    final maxCount = top.isEmpty ? 1 : top.first.value;

    // Build daily scan count for the last 7 days (sparkline)
    final dailyCounts = List.generate(7, (i) {
      final day = DateTime.now().subtract(Duration(days: 6 - i));
      return recentScans.where((s) =>
          s.scannedAt.year == day.year &&
          s.scannedAt.month == day.month &&
          s.scannedAt.day == day.day).length;
    });

    // Severity breakdown
    final highCount = recentScans.where((s) => s.severity == 'high').length;
    final medCount = recentScans.where((s) => s.severity == 'medium').length;
    final lowCount = recentScans.where((s) => s.severity == 'low').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _appBar(isRTL, context),
      bottomNavigationBar: const BottomNav(active: ''),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period selector
            Row(
              children: [
                _PeriodChip(
                    label: isRTL ? '٧ أيام' : '7 Days',
                    value: '7',
                    selected: _period == '7',
                    onTap: () => setState(() => _period = '7')),
                const SizedBox(width: 8),
                _PeriodChip(
                    label: isRTL ? '٣٠ يومًا' : '30 Days',
                    value: '30',
                    selected: _period == '30',
                    onTap: () => setState(() => _period = '30')),
                const SizedBox(width: 8),
                _PeriodChip(
                    label: isRTL ? '٩٠ يومًا' : '90 Days',
                    value: '90',
                    selected: _period == '90',
                    onTap: () => setState(() => _period = '90')),
              ],
            ),
            const SizedBox(height: 16),

            // KPI row
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    icon: Icons.pest_control_rounded,
                    label: isRTL ? 'حالات المرض' : 'Disease Cases',
                    value: '${recentScans.length}',
                    color: const Color(0xFFF44336),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    icon: Icons.biotech_rounded,
                    label: isRTL ? 'أنواع فريدة' : 'Unique Types',
                    value: '${freq.length}',
                    color: const Color(0xFF9C27B0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    icon: Icons.warning_amber_rounded,
                    label: isRTL ? 'خطر عالٍ' : 'High Risk',
                    value: '$highCount',
                    color: const Color(0xFFFF5722),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 7-day sparkline
            _SectionCard(
              title: isRTL ? 'النشاط اليومي (٧ أيام)' : 'Daily Activity (7 days)',
              child: _Sparkline(counts: dailyCounts, isRTL: isRTL),
            ),
            const SizedBox(height: 16),

            // Severity breakdown
            _SectionCard(
              title: isRTL ? 'توزيع الشدة' : 'Severity Breakdown',
              child: Column(
                children: [
                  _SeverityRow(
                    label: isRTL ? 'عالية' : 'High',
                    count: highCount,
                    total: recentScans.isEmpty ? 1 : recentScans.length,
                    color: const Color(0xFFF44336),
                  ),
                  const SizedBox(height: 8),
                  _SeverityRow(
                    label: isRTL ? 'متوسطة' : 'Medium',
                    count: medCount,
                    total: recentScans.isEmpty ? 1 : recentScans.length,
                    color: const Color(0xFFFFC107),
                  ),
                  const SizedBox(height: 8),
                  _SeverityRow(
                    label: isRTL ? 'منخفضة' : 'Low',
                    count: lowCount,
                    total: recentScans.isEmpty ? 1 : recentScans.length,
                    color: const Color(0xFF4CAF50),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Top diseases bar chart
            _SectionCard(
              title: isRTL ? 'أكثر الأمراض شيوعًا' : 'Most Frequent Diseases',
              child: top.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        isRTL ? 'لا توجد بيانات بعد' : 'No data yet',
                        style: const TextStyle(
                            color: Color(0xFF9E9E9E), fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: top.map((e) {
                        final pct = e.value / maxCount;
                        final colors = [
                          const Color(0xFF1976D2),
                          const Color(0xFF388E3C),
                          const Color(0xFFF57C00),
                          const Color(0xFF7B1FA2),
                          const Color(0xFF0097A7),
                          const Color(0xFFE64A19),
                          const Color(0xFF5D4037),
                          const Color(0xFF455A64),
                        ];
                        final idx = top.indexOf(e) % colors.length;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.key,
                                      style: const TextStyle(
                                        color: Color(0xFF424242),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${e.value}x',
                                    style: TextStyle(
                                      color: colors[idx],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 8,
                                  backgroundColor: const Color(0xFFF1F1F1),
                                  valueColor:
                                      AlwaysStoppedAnimation(colors[idx]),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(bool isRTL, BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
      ),
      title: Text(
        isRTL ? 'تحليلات الأمراض' : 'Disease Trends',
        style: const TextStyle(
            color: AppColors.primaryDark, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  const _PeriodChip(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onTap});
  final String label, value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE0E0E0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF616161),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  final IconData icon;
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9E9E9E), fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.counts, required this.isRTL});
  final List<int> counts;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxVal = counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final pct = maxVal == 0 ? 0.0 : counts[i] / maxVal;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (counts[i] > 0)
                  Text(
                    '${counts[i]}',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: (60 * pct).clamp(4.0, 60.0),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  days[i].substring(0, 2),
                  style: const TextStyle(
                      color: Color(0xFF9E9E9E), fontSize: 10),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _SeverityRow extends StatelessWidget {
  const _SeverityRow(
      {required this.label,
      required this.count,
      required this.total,
      required this.color});
  final String label;
  final int count, total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = count / total;
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFF616161),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: const Color(0xFFF5F5F5),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '$count',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
