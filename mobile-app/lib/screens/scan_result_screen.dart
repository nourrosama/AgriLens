import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';

class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    // Get scan result from route extra
    final extra = GoRouterState.of(context).extra;
    ScanResult? result;
    if (extra is ScanResult) {
      result = extra;
    }

    // Fallback to latest scan from provider
    if (result == null) {
      final scans = context.watch<ScanHistoryProvider>().scans;
      if (scans.isNotEmpty) result = scans.first;
    }

    final diseaseName = result != null
        ? (lang.isRTL ? result.diseaseNameAr : result.diseaseNameEn)
        : (lang.isRTL ? 'اللفحة المتأخرة' : 'Late Blight');
    final scientificName = result?.scientificName ?? 'Phytophthora infestans';
    final confidence = result != null ? (result.confidence * 100).round() : 92;
    final severity = result?.severity ?? 'medium';
    final recommendation = result?.recommendation ?? '';
    final isHealthy = result?.isHealthy ?? false;

    final severityLabel = severity == 'high'
        ? lang.t('disease.high')
        : severity == 'medium'
            ? lang.t('disease.medium')
            : lang.t('disease.low');
    final severityColor = severity == 'high'
        ? const Color(0xFFF44336)
        : severity == 'medium'
            ? const Color(0xFFFFC107)
            : const Color(0xFF4CAF50);
    final severityPercent = severity == 'high'
        ? 0.85
        : severity == 'medium'
            ? 0.60
            : 0.30;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Header ────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
              8,
              MediaQuery.of(context).padding.top + 8,
              24,
              16,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/home'),
                  icon: Icon(
                    Icons.arrow_back,
                    size: 28,
                    color: const Color(0xFF424242),
                    textDirection: lang.isRTL
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                ),
                Text(
                  lang.t('scan.resultTitle'),
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFE0E0E0)),

          // ── Body ──────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Captured Image Preview
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0x334CAF50),
                              Color(0x332E7D32),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            lang.isRTL
                                ? 'صورة الورقة الملتقطة'
                                : 'Captured Leaf Image',
                            style: const TextStyle(
                              color: Color(0xFF424242),
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Disease Information
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isHealthy
                                        ? lang.t('scan.healthy')
                                        : diseaseName,
                                    style: const TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    scientificName,
                                    style: const TextStyle(
                                      color: Color(0xFF424242),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isHealthy
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: severityColor,
                              size: 28,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Severity
                        _buildBar(
                          lang.t('scan.severity'),
                          severityLabel,
                          severityPercent,
                          severityColor,
                          gradient: true,
                        ),
                        const SizedBox(height: 16),

                        // Confidence
                        _buildBar(
                          lang.t('scan.confidence'),
                          '$confidence${lang.t('units.percent')}',
                          confidence / 100,
                          const Color(0xFF4CAF50),
                        ),
                        const SizedBox(height: 16),

                        // Recommendation
                        if (recommendation.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.t('disease.recommendedAction'),
                                  style: const TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildRecommendation(
                                  recommendation,
                                  Icons.check_circle,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  GestureDetector(
                    onTap: () => context.push('/disease-details',
                        extra: result),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50)
                                .withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.white, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            lang.t('scan.viewDetails'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => context.go('/scan'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: const Color(0xFF4CAF50), width: 2),
                      ),
                      child: Text(
                        lang.t('scan.scanAnother'),
                        style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
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

  Widget _buildBar(
    String label,
    String value,
    double percent,
    Color color, {
    bool gradient = false,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF424242),
                fontSize: 18,
              ),
            ),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: const Color(0xFFF5F5F5),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendation(String text, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF4CAF50), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF424242),
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
