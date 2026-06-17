import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/bottom_nav.dart';
import 'package:agrilens/widgets/plan_gate.dart';

class DiseaseHistoryScreen extends StatefulWidget {
  const DiseaseHistoryScreen({super.key});

  @override
  State<DiseaseHistoryScreen> createState() => _DiseaseHistoryScreenState();
}

class _DiseaseHistoryScreenState extends State<DiseaseHistoryScreen> {
  String _filter = 'all'; // all | high | medium | low

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ScanHistoryProvider>().loadScans();
    });
  }

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

    final allScans = scanProvider.scans
        .where((s) => s.hasDetection && !s.isHealthy)
        .toList();

    final filtered = _filter == 'all'
        ? allScans
        : allScans.where((s) => s.severity == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _appBar(isRTL, context),
      bottomNavigationBar: const BottomNav(active: ''),
      body: Column(
        children: [
          // Summary chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _SummaryChip(
                  label: isRTL ? 'الكل' : 'All',
                  count: allScans.length,
                  color: const Color(0xFF4CAF50),
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: isRTL ? 'عالية' : 'High',
                  count: allScans.where((s) => s.severity == 'high').length,
                  color: const Color(0xFFF44336),
                  selected: _filter == 'high',
                  onTap: () => setState(() => _filter = 'high'),
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: isRTL ? 'متوسطة' : 'Medium',
                  count: allScans.where((s) => s.severity == 'medium').length,
                  color: const Color(0xFFFFC107),
                  selected: _filter == 'medium',
                  onTap: () => setState(() => _filter = 'medium'),
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: isRTL ? 'منخفضة' : 'Low',
                  count: allScans.where((s) => s.severity == 'low').length,
                  color: const Color(0xFF4CAF50),
                  selected: _filter == 'low',
                  onTap: () => setState(() => _filter = 'low'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Timeline list
          Expanded(
            child: scanProvider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : filtered.isEmpty
                    ? _EmptyHistory(isRTL: isRTL)
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () =>
                            context.read<ScanHistoryProvider>().loadScans(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final scan = filtered[i];
                            final isLast = i == filtered.length - 1;
                            return _TimelineItem(
                              scan: scan,
                              isLast: isLast,
                              isRTL: isRTL,
                            );
                          },
                        ),
                      ),
          ),
        ],
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
        isRTL ? 'سجل الأمراض' : 'Disease History',
        style: const TextStyle(
            color: AppColors.primaryDark, fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.primary),
          onPressed: () => context.read<ScanHistoryProvider>().loadScans(),
        ),
      ],
    );
  }
}

// ─── Summary chip ─────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : const Color(0xFFE0E0E0)),
        ),
        child: Text(
          '$label ($count)',
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

// ─── Timeline item ────────────────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.scan,
    required this.isLast,
    required this.isRTL,
  });
  final ScanResult scan;
  final bool isLast;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    final severityColor = scan.severity == 'high'
        ? const Color(0xFFF44336)
        : scan.severity == 'medium'
            ? const Color(0xFFFFC107)
            : const Color(0xFF4CAF50);

    final dateStr = _formatDate(scan.scannedAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline rail
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: severityColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: severityColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1))
                ],
              ),
            ),
            if (!isLast)
              Container(
                  width: 2,
                  height: 88,
                  color: const Color(0xFFE0E0E0)),
          ],
        ),
        const SizedBox(width: 12),

        // Card
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/scan-result', extra: scan),
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          scan.diseaseNameEn,
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: severityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          scan.severity.toUpperCase(),
                          style: TextStyle(
                            color: severityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.eco_rounded,
                          size: 13, color: Color(0xFF757575)),
                      const SizedBox(width: 4),
                      Text(
                        scan.cropType.isEmpty
                            ? (isRTL ? 'غير محدد' : 'Unknown crop')
                            : scan.cropType,
                        style: const TextStyle(
                            color: Color(0xFF757575), fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: Color(0xFF757575)),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                            color: Color(0xFF757575), fontSize: 12),
                      ),
                    ],
                  ),
                  if (scan.confidence > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          isRTL ? 'الثقة: ' : 'Confidence: ',
                          style: const TextStyle(
                              color: Color(0xFF9E9E9E), fontSize: 11),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: scan.confidence.clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: const Color(0xFFF5F5F5),
                              valueColor: AlwaysStoppedAnimation(
                                  AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(scan.confidence * 100).round()}%',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.isRTL});
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded,
                size: 72, color: Color(0xFFBDBDBD)),
            const SizedBox(height: 16),
            Text(
              isRTL ? 'لا يوجد سجل أمراض بعد' : 'No disease history yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF616161),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isRTL
                  ? 'ابدأ بمسح النباتات لتتبع تاريخ الأمراض'
                  : 'Start scanning plants to track disease history',
              style: const TextStyle(
                  color: Color(0xFF9E9E9E), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
