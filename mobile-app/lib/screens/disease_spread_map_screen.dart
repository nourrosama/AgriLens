import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/fields_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/plan_gate.dart';

class DiseaseSpreadMapScreen extends StatefulWidget {
  const DiseaseSpreadMapScreen({super.key});

  @override
  State<DiseaseSpreadMapScreen> createState() =>
      _DiseaseSpreadMapScreenState();
}

class _DiseaseSpreadMapScreenState extends State<DiseaseSpreadMapScreen> {
  String? _selectedFieldId;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();
    final scanProvider = context.watch<ScanHistoryProvider>();
    final fieldsProvider = context.watch<FieldsProvider>();
    final isRTL = lang.isRTL;

    if (user.plan != 'professional') {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back,
                color: AppColors.textSecondary),
          ),
          title: Text(
            isRTL ? 'خريطة انتشار الأمراض' : 'Disease Spread Map',
            style: const TextStyle(
                color: AppColors.primaryDark, fontWeight: FontWeight.bold),
          ),
        ),
        body: PlanGateBody(requiredPlan: 'professional', isRTL: isRTL),
      );
    }

    final fields = fieldsProvider.fields;
    final scans = scanProvider.scans
        .where((s) => s.hasDetection && !s.isHealthy)
        .toList();

    // Build per-field disease stats
    final Map<String, List<ScanResult>> fieldScans = {};
    for (final s in scans) {
      if (s.fieldId != null) {
        fieldScans.putIfAbsent(s.fieldId!, () => []).add(s);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back,
              color: AppColors.textSecondary),
        ),
        title: Text(
          isRTL ? 'خريطة انتشار الأمراض' : 'Disease Spread Map',
          style: const TextStyle(
              color: AppColors.primaryDark, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Legend
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  isRTL ? 'المؤشر: ' : 'Legend: ',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                _LegendDot(
                    color: const Color(0xFFF44336),
                    label: isRTL ? 'عالية' : 'High'),
                const SizedBox(width: 12),
                _LegendDot(
                    color: const Color(0xFFFFC107),
                    label: isRTL ? 'متوسطة' : 'Med'),
                const SizedBox(width: 12),
                _LegendDot(
                    color: const Color(0xFF4CAF50),
                    label: isRTL ? 'منخفضة' : 'Low'),
                const SizedBox(width: 12),
                _LegendDot(
                    color: const Color(0xFFE0E0E0),
                    label: isRTL ? 'سليم' : 'Healthy'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Visual grid map
          Expanded(
            child: fields.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined,
                              size: 64, color: Color(0xFFBDBDBD)),
                          const SizedBox(height: 12),
                          Text(
                            isRTL
                                ? 'لا توجد حقول مضافة بعد'
                                : 'No fields added yet',
                            style: const TextStyle(
                                color: Color(0xFF616161),
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () =>
                                context.push('/add-field'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white),
                            child: Text(isRTL ? 'إضافة حقل' : 'Add Field'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Farm overview grid
                        _MapGrid(
                          fields: fields,
                          fieldScans: fieldScans,
                          selectedId: _selectedFieldId,
                          onSelect: (id) =>
                              setState(() => _selectedFieldId =
                                  _selectedFieldId == id ? null : id),
                          isRTL: isRTL,
                        ),
                        const SizedBox(height: 16),

                        // Selected field detail
                        if (_selectedFieldId != null) ...[
                          _FieldDetail(
                            fieldId: _selectedFieldId!,
                            fields: fields,
                            fieldScans: fieldScans,
                            isRTL: isRTL,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Summary table
                        _SummaryTable(
                          fields: fields,
                          fieldScans: fieldScans,
                          isRTL: isRTL,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF616161), fontSize: 11)),
      ],
    );
  }
}

Color _fieldSeverityColor(List<ScanResult>? scans) {
  if (scans == null || scans.isEmpty) return const Color(0xFFE0E0E0);
  if (scans.any((s) => s.severity == 'high')) return const Color(0xFFF44336);
  if (scans.any((s) => s.severity == 'medium')) return const Color(0xFFFFC107);
  return const Color(0xFF4CAF50);
}

class _MapGrid extends StatelessWidget {
  const _MapGrid({
    required this.fields,
    required this.fieldScans,
    required this.selectedId,
    required this.onSelect,
    required this.isRTL,
  });
  final List fields;
  final Map<String, List<ScanResult>> fieldScans;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRTL ? 'نظرة عامة على المزرعة' : 'Farm Overview',
            style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 15,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: fields.length,
            itemBuilder: (ctx, i) {
              final f = fields[i];
              final id = f.id ?? '';
              final scansForField = fieldScans[id];
              final color = _fieldSeverityColor(scansForField);
              final isSelected = selectedId == id;
              return GestureDetector(
                onTap: () => onSelect(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? color : color.withValues(alpha: 0.5),
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.grass_rounded,
                          color: color, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        (f.name ?? 'Field ${i + 1}').length > 10
                            ? '${(f.name ?? 'Field ${i + 1}').substring(0, 9)}…'
                            : (f.name ?? 'Field ${i + 1}'),
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if ((scansForField?.length ?? 0) > 0)
                        Text(
                          '${scansForField!.length}',
                          style: TextStyle(
                              color: color,
                              fontSize: 10),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FieldDetail extends StatelessWidget {
  const _FieldDetail({
    required this.fieldId,
    required this.fields,
    required this.fieldScans,
    required this.isRTL,
  });
  final String fieldId;
  final List fields;
  final Map<String, List<ScanResult>> fieldScans;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    final field = fields.firstWhere((f) => f.id == fieldId,
        orElse: () => null);
    final scans = fieldScans[fieldId] ?? [];
    final color = _fieldSeverityColor(scans.isEmpty ? null : scans);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grass_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                field?.name ?? 'Field',
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (scans.isEmpty)
            Text(
              isRTL ? 'لا توجد أمراض مسجلة' : 'No diseases recorded',
              style: const TextStyle(
                  color: AppColors.textSecondary),
            )
          else
            ...scans.take(3).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: _fieldSeverityColor([s]),
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(s.diseaseNameEn,
                              style: const TextStyle(
                                  fontSize: 13),
                              overflow: TextOverflow.ellipsis)),
                      Text(
                        '${(s.confidence * 100).round()}%',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _SummaryTable extends StatelessWidget {
  const _SummaryTable({
    required this.fields,
    required this.fieldScans,
    required this.isRTL,
  });
  final List fields;
  final Map<String, List<ScanResult>> fieldScans;
  final bool isRTL;

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
              isRTL ? 'ملخص الحالة' : 'Status Summary',
              style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          ...fields.take(5).map((f) {
            final scans = fieldScans[f.id ?? ''] ?? [];
            final color = _fieldSeverityColor(scans.isEmpty ? null : scans);
            return ListTile(
              dense: true,
              leading: Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              title: Text(f.name ?? 'Field',
                  style: const TextStyle(fontSize: 13)),
              trailing: Text(
                scans.isEmpty
                    ? (isRTL ? 'سليم' : 'Healthy')
                    : '${scans.length} ${isRTL ? 'حالة' : 'cases'}',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            );
          }),
        ],
      ),
    );
  }
}
