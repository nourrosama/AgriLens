import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/fields_provider.dart';

/// Disease Map screen — matches TSX DiseaseMap.tsx exactly:
/// Map with field zones, zoom controls, severity scale legend, summary card
class DiseaseMapScreen extends StatelessWidget {
  const DiseaseMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final fieldsProvider = context.watch<FieldsProvider>();
    final fields = fieldsProvider.fields;

    final healthyCount = fields.where((f) => f.health >= 80).length;
    final monitorCount = fields.where((f) => f.health < 80).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go('/fields'),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Transform.flip(
                    flipX: lang.isRTL,
                    child: const Icon(Icons.arrow_back, size: 28, color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  lang.isRTL ? 'خريطة الأمراض' : 'Disease Map',
                  style: const TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.layers_rounded, size: 28, color: AppColors.textPrimary),
              ),
            ]),
          ),

          // Map area (60vh)
          Expanded(
            flex: 6,
            child: Stack(children: [
              // Map background gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                  ),
                ),
              ),

              // Field zones
              if (fields.isNotEmpty) ...[
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.08,
                  left: MediaQuery.of(context).size.width * 0.15,
                  child: _fieldZone(
                    fields.length > 0 ? fields[0].name : 'Field A',
                    128,
                    fields.length > 0 && fields[0].health >= 80 ? AppColors.primary : const Color(0xFFFFC107),
                  ),
                ),
                if (fields.length > 1)
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.12,
                    right: MediaQuery.of(context).size.width * 0.1,
                    child: _fieldZone(
                      fields[1].name,
                      160,
                      fields[1].health >= 80 ? AppColors.primary : const Color(0xFFFFC107),
                    ),
                  ),
                if (fields.length > 2)
                  Positioned(
                    bottom: MediaQuery.of(context).size.height * 0.08,
                    left: MediaQuery.of(context).size.width * 0.25,
                    child: _fieldZone(
                      fields[2].name,
                      112,
                      fields[2].health >= 80 ? AppColors.primary : const Color(0xFFFFC107),
                    ),
                  ),
              ],

              // Zoom controls
              Positioned(
                top: 16,
                right: lang.isRTL ? null : 16,
                left: lang.isRTL ? 16 : null,
                child: Column(children: [
                  _zoomButton(Icons.add),
                  const SizedBox(height: 8),
                  _zoomButton(Icons.remove),
                ]),
              ),
            ]),
          ),

          // Severity Scale + Summary
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                // Severity Scale
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      lang.isRTL ? 'مقياس الشدة' : 'Severity Scale',
                      style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    _severityItem(const Color(0xFF4CAF50), lang.t('fields.healthy'),
                        lang.isRTL ? 'لم يتم اكتشاف أمراض' : 'No diseases detected'),
                    const SizedBox(height: 12),
                    _severityItem(const Color(0xFF8BC34A), lang.isRTL ? 'خطر منخفض' : 'Low Risk',
                        lang.isRTL ? 'أعراض طفيفة موجودة' : 'Minor symptoms present'),
                    const SizedBox(height: 12),
                    _severityItem(const Color(0xFFFFC107), lang.isRTL ? 'خطر متوسط' : 'Moderate',
                        lang.isRTL ? 'يوصى باتخاذ إجراء' : 'Action recommended'),
                    const SizedBox(height: 12),
                    _severityItem(const Color(0xFFFF9800), lang.isRTL ? 'خطر عالي' : 'High Risk',
                        lang.isRTL ? 'مطلوب إجراء فوري' : 'Immediate action required'),
                    const SizedBox(height: 12),
                    _severityItem(const Color(0xFFF44336), lang.isRTL ? 'حرج' : 'Critical',
                        lang.isRTL ? 'إصابة شديدة' : 'Severe infection'),
                  ]),
                ),
                const SizedBox(height: 16),

                // Summary card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      lang.isRTL ? 'ملخص' : 'Summary',
                      style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _summaryRow(lang.isRTL ? 'إجمالي الحقول' : 'Total Fields', '${fields.length}', AppColors.primaryDark),
                    const SizedBox(height: 8),
                    _summaryRow(lang.isRTL ? 'حقول صحية' : 'Healthy Fields', '$healthyCount', AppColors.primary),
                    const SizedBox(height: 8),
                    _summaryRow(lang.isRTL ? 'تتطلب مراقبة' : 'Monitoring Required', '$monitorCount', const Color(0xFFFFC107)),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _fieldZone(String name, double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          name,
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 14),
        ),
      ),
    );
  }

  Widget _zoomButton(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12)],
      ),
      child: Icon(icon, size: 24, color: AppColors.textPrimary),
    );
  }

  Widget _severityItem(Color color, String title, String desc) {
    return Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppColors.primaryDark, fontSize: 16)),
          Text(desc, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        ]),
      ),
    ]);
  }

  Widget _summaryRow(String label, String value, Color valueColor) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
      Text(value, style: TextStyle(color: valueColor, fontSize: 16)),
    ]);
  }
}
