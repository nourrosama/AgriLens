import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/fields_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';

class DiseaseMapScreen extends StatelessWidget {
  const DiseaseMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final fieldsProvider = context.watch<FieldsProvider>();
    final fields = fieldsProvider.fields;

    final markerFields = fields
        .map((field) => (field: field, point: _extractPoint(field)))
        .where((item) => item.point != null)
        .toList();
    final center = markerFields.isNotEmpty
        ? markerFields.first.point!
        : const LatLng(30.0444, 31.2357);

    final healthyCount = fields.where((field) => field.health >= 80).length;
    final monitorCount = fields.where((field) => field.health < 80).length;

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
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      lang.isRTL ? 'خريطة الحقول' : 'Field Map',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.layers_outlined,
                    size: 28,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: Container(
                color: Colors.white,
                child: markerFields.isEmpty
                    ? _mapFallback(lang)
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 10,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.agrilens.mobile',
                          ),
                          MarkerLayer(
                            markers: markerFields.map((item) {
                              final statusColor = item.field.health >= 80
                                  ? AppColors.primary
                                  : const Color(0xFFFFC107);
                              return Marker(
                                point: item.point!,
                                width: 120,
                                height: 70,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(color: statusColor),
                                      ),
                                      child: Text(
                                        item.field.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Icon(
                                      Icons.location_on,
                                      color: statusColor,
                                      size: 28,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
              ),
            ),
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.isRTL ? 'مقياس الحالة' : 'Status Legend',
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _legendItem(
                            AppColors.primary,
                            lang.t('fields.healthy'),
                            lang.isRTL
                                ? 'صحة مستقرة أو خطر منخفض'
                                : 'Stable health or low disease risk',
                          ),
                          const SizedBox(height: 12),
                          _legendItem(
                            const Color(0xFFFFC107),
                            lang.t('fields.warning'),
                            lang.isRTL
                                ? 'تحتاج إلى متابعة أو فحص جديد'
                                : 'Needs attention or a fresh scan',
                          ),
                          const SizedBox(height: 12),
                          _legendItem(
                            const Color(0xFFF44336),
                            lang.t('forecast.highRisk'),
                            lang.isRTL
                                ? 'إجراءات عاجلة مطلوبة'
                                : 'Urgent action recommended',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.isRTL ? 'الملخص' : 'Summary',
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _summaryRow(
                            lang.t('fields.totalFields'),
                            '${fields.length}',
                            AppColors.primaryDark,
                          ),
                          const SizedBox(height: 8),
                          _summaryRow(
                            lang.t('fields.healthy'),
                            '$healthyCount',
                            AppColors.primary,
                          ),
                          const SizedBox(height: 8),
                          _summaryRow(
                            lang.isRTL ? 'تحتاج متابعة' : 'Needs monitoring',
                            '$monitorCount',
                            const Color(0xFFFFC107),
                          ),
                          if (markerFields.isEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              lang.isRTL
                                  ? 'أضف إحداثيات للحقل لعرضه على الخريطة. حالياً يتم عرض قائمة منظمة فقط.'
                                  : 'Add coordinates to a field to show it on the map. For now, a structured list is shown instead.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (fields.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.t('fields.title'),
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...fields.map(
                              (field) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: field.health >= 80
                                            ? AppColors.primary
                                            : const Color(0xFFFFC107),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        field.name,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${field.health}${lang.t('units.percent')}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LatLng? _extractPoint(FieldData field) {
    final data = field.locationData;
    final lat = double.tryParse('${data['lat'] ?? data['latitude'] ?? ''}');
    final lng = double.tryParse(
      '${data['lng'] ?? data['lon'] ?? data['longitude'] ?? ''}',
    );
    if (lat == null || lng == null) {
      return null;
    }
    return LatLng(lat, lng);
  }

  Widget _mapFallback(LanguageProvider lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.map_outlined,
              size: 52,
              color: AppColors.primaryDark,
            ),
            const SizedBox(height: 16),
            Text(
              lang.isRTL
                  ? 'لا توجد إحداثيات خريطة متاحة'
                  : 'No map coordinates available',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lang.isRTL
                  ? 'يمكنك الاستمرار في متابعة الحقول من القائمة إلى أن تتم إضافة المواقع.'
                  : 'You can still monitor fields from the list until precise locations are added.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String title, String description) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        Text(value, style: TextStyle(color: valueColor, fontSize: 16)),
      ],
    );
  }
}
