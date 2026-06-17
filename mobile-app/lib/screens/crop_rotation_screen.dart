import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/fields_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/plan_gate.dart';

// ─── Rotation advice map ─────────────────────────────────────────────────────
// Maps a disease name fragment → crop to avoid → crops to rotate in
const Map<String, _RotationRule> _rotationRules = {
  'blight': _RotationRule(
    avoid: ['tomato', 'potato', 'pepper'],
    suggest: ['wheat', 'corn', 'legumes', 'garlic'],
    tip: 'Late blight pathogens survive in soil; avoid nightshade family for 2–3 seasons.',
    tipAr: 'تبقى مسببات اللفحة في التربة؛ تجنب عائلة الباذنجانيات لموسمين إلى ثلاثة مواسم.',
  ),
  'rust': _RotationRule(
    avoid: ['wheat', 'barley', 'rye'],
    suggest: ['soybean', 'sunflower', 'potato', 'beets'],
    tip: 'Rust spores persist on infected stubble; rotate to broadleaf crops for at least 1 season.',
    tipAr: 'تبقى جراثيم الصدأ على الحشائش المصابة؛ حوّل إلى المحاصيل ذات الأوراق العريضة لموسم واحد على الأقل.',
  ),
  'mildew': _RotationRule(
    avoid: ['cucumber', 'melon', 'squash'],
    suggest: ['corn', 'beans', 'onion', 'carrot'],
    tip: 'Powdery/downy mildew thrives in cucurbit crops; break the cycle with unrelated species.',
    tipAr: 'البياض يزدهر في محاصيل القرعيات؛ اقطع الدورة بمحاصيل غير مرتبطة.',
  ),
  'wilt': _RotationRule(
    avoid: ['cotton', 'tomato', 'eggplant'],
    suggest: ['sorghum', 'wheat', 'corn', 'alfalfa'],
    tip: 'Fusarium/Verticillium wilt persists in soil for years; rotate to non-host crops.',
    tipAr: 'تبقى ذبول الفيوزاريوم/الفيرتيسيليوم في التربة لسنوات؛ حوّل إلى محاصيل غير عائلة.',
  ),
  'leaf spot': _RotationRule(
    avoid: ['peanut', 'soybean'],
    suggest: ['corn', 'small grains', 'vegetables'],
    tip: 'Leaf spot inoculum in crop debris; rotate out of legumes for 1–2 seasons.',
    tipAr: 'بقع الأوراق تعيش في مخلفات المحاصيل؛ حوّل بعيدًا عن البقوليات لموسم أو موسمين.',
  ),
  'default': _RotationRule(
    avoid: [],
    suggest: ['legumes', 'small grains', 'brassicas'],
    tip: 'General best practice: rotate between plant families to break pest and disease cycles.',
    tipAr: 'الممارسة الأفضل: حوّل بين عائلات النباتات لكسر دورات الآفات والأمراض.',
  ),
};

class _RotationRule {
  const _RotationRule({
    required this.avoid,
    required this.suggest,
    required this.tip,
    required this.tipAr,
  });
  final List<String> avoid;
  final List<String> suggest;
  final String tip;
  final String tipAr;
}

_RotationRule _ruleForDisease(String disease) {
  final d = disease.toLowerCase();
  for (final key in _rotationRules.keys) {
    if (key != 'default' && d.contains(key)) return _rotationRules[key]!;
  }
  return _rotationRules['default']!;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CropRotationScreen extends StatefulWidget {
  const CropRotationScreen({super.key});

  @override
  State<CropRotationScreen> createState() => _CropRotationScreenState();
}

class _CropRotationScreenState extends State<CropRotationScreen> {
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
        appBar: _appBar(isRTL, context),
        body: PlanGateBody(requiredPlan: 'professional', isRTL: isRTL),
      );
    }

    final fields = fieldsProvider.fields;

    // Per-field disease history
    final Map<String, List<ScanResult>> fieldScans = {};
    for (final s in scanProvider.scans) {
      if (s.fieldId != null && s.hasDetection && !s.isHealthy) {
        fieldScans.putIfAbsent(s.fieldId!, () => []).add(s);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _appBar(isRTL, context),
      body: fields.isEmpty
          ? _EmptyState(isRTL: isRTL)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info banner
                _InfoBanner(isRTL: isRTL),
                const SizedBox(height: 16),

                // Field selector
                Text(
                  isRTL ? 'اختر الحقل:' : 'Select Field:',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: fields.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final f = fields[i];
                      final id = f.id ?? '';
                      final selected = _selectedFieldId == id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFieldId = id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          child: Text(
                            f.name ?? 'Field ${i + 1}',
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF616161),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Content — show for selected field or all fields
                if (_selectedFieldId != null)
                  _FieldRotationCard(
                    fieldId: _selectedFieldId!,
                    fields: fields,
                    scans: fieldScans[_selectedFieldId!] ?? [],
                    isRTL: isRTL,
                  )
                else
                  ...fields.map((f) {
                    final id = f.id ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FieldRotationCard(
                        fieldId: id,
                        fields: fields,
                        scans: fieldScans[id] ?? [],
                        isRTL: isRTL,
                      ),
                    );
                  }),
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
        child:
            const Icon(Icons.arrow_back, color: AppColors.textSecondary),
      ),
      title: Text(
        isRTL ? 'مخطط تدوير المحاصيل' : 'Crop Rotation Planner',
        style: const TextStyle(
            color: AppColors.primaryDark, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.isRTL});
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isRTL
                  ? 'يقترح هذا القسم تدوير المحاصيل استنادًا إلى تاريخ الأمراض المسجل لكل حقل.'
                  : 'Rotation suggestions are based on the recorded disease history for each field.',
              style: const TextStyle(
                  color: AppColors.primaryDark, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldRotationCard extends StatelessWidget {
  const _FieldRotationCard({
    required this.fieldId,
    required this.fields,
    required this.scans,
    required this.isRTL,
  });
  final String fieldId;
  final List fields;
  final List<ScanResult> scans;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    final field =
        fields.firstWhere((f) => f.id == fieldId, orElse: () => null);
    final fieldName = field?.name ?? 'Field';

    // Aggregate unique diseases
    final diseases =
        scans.map((s) => s.diseaseNameEn).toSet().toList();

    // Pick the most relevant rotation rule
    final rule = diseases.isEmpty
        ? _rotationRules['default']!
        : _ruleForDisease(diseases.first);

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
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.grass_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fieldName,
                    style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
                if (diseases.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFF9800)),
                    ),
                    child: Text(
                      '${diseases.length} ${isRTL ? 'مرض' : 'disease${diseases.length > 1 ? 's' : ''}'}',
                      style: const TextStyle(
                          color: Color(0xFFE65100),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Disease history
                if (diseases.isNotEmpty) ...[
                  _SectionLabel(
                      icon: Icons.bug_report_outlined,
                      label: isRTL
                          ? 'الأمراض المسجلة:'
                          : 'Recorded Diseases:',
                      color: const Color(0xFFF44336)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: diseases
                        .map((d) => _Tag(
                            label: d,
                            bg: const Color(0xFFFFEBEE),
                            fg: const Color(0xFFC62828)))
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  Text(
                    isRTL
                        ? 'لا توجد أمراض مسجلة — الحقل يبدو بصحة جيدة!'
                        : 'No diseases recorded — field looks healthy!',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                ],

                // Avoid
                if (rule.avoid.isNotEmpty) ...[
                  _SectionLabel(
                      icon: Icons.not_interested_rounded,
                      label: isRTL
                          ? 'تجنب زراعة:'
                          : 'Avoid Planting:',
                      color: const Color(0xFFFF5722)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: rule.avoid
                        .map((c) => _Tag(
                            label: c,
                            bg: const Color(0xFFFBE9E7),
                            fg: const Color(0xFFBF360C)))
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Suggest
                _SectionLabel(
                    icon: Icons.recommend_rounded,
                    label: isRTL
                        ? 'يُوصى بزراعة:'
                        : 'Recommended Crops:',
                    color: AppColors.primary),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: rule.suggest
                      .map((c) => _Tag(
                          label: c,
                          bg: const Color(0xFFE8F5E9),
                          fg: const Color(0xFF1B5E20)))
                      .toList(),
                ),
                const SizedBox(height: 14),

                // Agronomic tip
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCE93D8)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded,
                          color: Color(0xFF7B1FA2), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isRTL ? rule.tipAr : rule.tip,
                          style: const TextStyle(
                              color: Color(0xFF4A148C),
                              fontSize: 12,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),

                // Rotation timeline visual
                const SizedBox(height: 16),
                _RotationTimeline(
                    suggest: rule.suggest, isRTL: isRTL),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(
      {required this.icon,
      required this.label,
      required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(
      {required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label[0].toUpperCase() + label.substring(1),
        style: TextStyle(
            color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RotationTimeline extends StatelessWidget {
  const _RotationTimeline(
      {required this.suggest, required this.isRTL});
  final List<String> suggest;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    final seasons = [
      isRTL ? 'الموسم ١' : 'Season 1',
      isRTL ? 'الموسم ٢' : 'Season 2',
      isRTL ? 'الموسم ٣' : 'Season 3',
      isRTL ? 'الموسم ٤' : 'Season 4',
    ];
    final crops = [
      ...suggest.take(4),
      ...List.filled((4 - suggest.length).clamp(0, 4), '—'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRTL ? 'جدول التدوير المقترح:' : 'Suggested Rotation Schedule:',
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.primaryDark),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Column(
                children: [
                  Container(
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withValues(alpha: 0.08 + i * 0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary
                              .withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        i < crops.length
                            ? (crops[i][0].toUpperCase() +
                                crops[i].substring(1))
                            : '—',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    seasons[i],
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isRTL});
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.agriculture_rounded,
                size: 72, color: Color(0xFFBDBDBD)),
            const SizedBox(height: 16),
            Text(
              isRTL
                  ? 'لا توجد حقول مضافة بعد'
                  : 'No fields added yet',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF616161)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isRTL
                  ? 'أضف حقولك لتحصل على توصيات تدوير المحاصيل'
                  : 'Add your fields to get crop rotation recommendations',
              style: const TextStyle(
                  color: Color(0xFF9E9E9E), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push('/add-field'),
              icon: const Icon(Icons.add_rounded),
              label: Text(isRTL ? 'إضافة حقل' : 'Add Field'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
