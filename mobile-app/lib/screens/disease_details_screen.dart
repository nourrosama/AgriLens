import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/connectivity_provider.dart';
import 'package:agrilens/core/disease_local_db.dart';
import 'package:agrilens/core/favourites_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/theme.dart';

class DiseaseDetailsScreen extends StatefulWidget {
  const DiseaseDetailsScreen({super.key});

  @override
  State<DiseaseDetailsScreen> createState() => _DiseaseDetailsScreenState();
}

class _DiseaseDetailsScreenState extends State<DiseaseDetailsScreen> {
  LocalDisease? _localDisease;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final result = _resolveResult(context);
    if (result != null && _localDisease == null) {
      DiseaseLocalDb.instance.findByName(result.diseaseNameEn).then((d) {
        if (mounted) setState(() => _localDisease = d);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isOnline = context.watch<ConnectivityProvider>().isOnline;
    final favourites = context.watch<FavouritesProvider>();
    final result = _resolveResult(context);

    final diseaseId = result?.diseaseNameEn ?? '';
    final isFav = favourites.isFavourite(diseaseId);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(context, lang, diseaseId, isFav, favourites),
            // Offline notice
            if (!isOnline)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFFFF3E0),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off,
                        size: 14, color: Color(0xFFE65100)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        lang.isRTL
                            ? 'غير متصل — يتم عرض المعلومات المحلية'
                            : 'Offline — showing locally stored info',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: result == null
                    ? const _DetailsEmptyState()
                    : Column(
                        children: [
                          _overviewCard(result: result),
                          const SizedBox(height: 20),
                          _summaryCard(result: result),
                          const SizedBox(height: 20),
                          _recommendationCard(result: result),
                          if (result.topPredictions.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _predictionsCard(result: result),
                          ],
                          // Local disease info (always shown; especially useful offline)
                          if (_localDisease != null) ...[
                            const SizedBox(height: 20),
                            _localInfoCard(lang, _localDisease!),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ScanResult? _resolveResult(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    if (extra is ScanResult) {
      return extra;
    }
    final scans = context.watch<ScanHistoryProvider>().scans;
    return scans.isEmpty ? null : scans.first;
  }

  Widget _header(
    BuildContext context,
    LanguageProvider lang,
    String diseaseId,
    bool isFav,
    FavouritesProvider favourites,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
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
              lang.t('disease.overview'),
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (diseaseId.isNotEmpty)
            GestureDetector(
              onTap: () => favourites.toggle(diseaseId),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  isFav ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 28,
                  color: isFav
                      ? const Color(0xFFFFC107)
                      : AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _localInfoCard(LanguageProvider lang, LocalDisease d) {
    final name = lang.isRTL ? d.nameAr : d.nameEn;
    final symptoms = lang.isRTL ? d.symptomsAr : d.symptomsEn;
    final treatment = lang.isRTL ? d.treatmentAr : d.treatmentEn;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.isRTL
                      ? 'معلومات محلية: $name'
                      : 'Offline Info: $name',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            lang.isRTL ? 'الأعراض' : 'Symptoms',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(symptoms,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5)),
          const SizedBox(height: 14),
          Text(
            lang.isRTL ? 'التوصية' : 'Basic Treatment',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(treatment,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5)),
        ],
      ),
    );
  }

  Widget _overviewCard({required ScanResult result}) {
    final icon = result.isHealthy ? Icons.check_circle : Icons.biotech_rounded;
    final iconColor = result.isHealthy
        ? const Color(0xFF4CAF50)
        : _severityColor(result.severity);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.isHealthy ? 'Healthy tomato leaf' : result.diseaseNameEn,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (result.scientificName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        result.scientificName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(icon, size: 30, color: iconColor),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _chip('Crop: ${result.cropType.isEmpty ? 'tomato' : result.cropType}'),
              _chip('Severity: ${result.severity}'),
              _chip('Risk: ${result.riskLevel}'),
              _chip('Confidence: ${(result.confidence * 100).round()}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({required ScanResult result}) {
    final scannedAt = result.scannedAt.toLocal().toString().replaceFirst('.000', '');
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detection Summary',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _detailRow('Scan ID', result.id),
          _detailRow('Media Type', result.mediaType),
          _detailRow('Status', result.status),
          _detailRow('Scanned At', scannedAt),
          if (result.modelVersion.isNotEmpty)
            _detailRow('Model Version', result.modelVersion),
          if (result.fieldId != null)
            _detailRow('Field ID', result.fieldId!),
          if (result.farmId != null)
            _detailRow('Farm ID', result.farmId!),
        ],
      ),
    );
  }

  Widget _recommendationCard({required ScanResult result}) {
    final body = result.recommendation.isEmpty
        ? 'No additional recommendation is available for this scan.'
        : result.recommendation;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended Action',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _predictionsCard({required ScanResult result}) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Model Alternatives',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...result.topPredictions.map((prediction) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          prediction.disease.isEmpty
                              ? prediction.label
                              : prediction.disease,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${(prediction.confidence * 100).round()}%',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: prediction.confidence.clamp(0, 1).toDouble(),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F1F1),
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
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

  Color _severityColor(String severity) {
    switch (severity) {
      case 'high':
        return const Color(0xFFF44336);
      case 'medium':
        return const Color(0xFFFFC107);
      default:
        return const Color(0xFF4CAF50);
    }
  }
}

class _DetailsEmptyState extends StatelessWidget {
  const _DetailsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.info_outline, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text(
            'No scan details available.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
