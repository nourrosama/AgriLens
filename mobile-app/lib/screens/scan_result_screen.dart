import 'dart:io';

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
    final result = _resolveResult(context);
    final severityColor = _severityColor(result?.severity);
    final severityLabel = _severityLabel(lang, result?.severity ?? 'none');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
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
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 28,
                    color: Color(0xFF424242),
                  ),
                ),
                Text(
                  lang.t('scan.resultTitle'),
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFE0E0E0)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: result == null
                  ? _EmptyState(lang: lang)
                  : Column(
                      children: [
                        _MediaPreview(result: result),
                        const SizedBox(height: 20),
                        _SummaryCard(
                          result: result,
                          lang: lang,
                          severityColor: severityColor,
                          severityLabel: severityLabel,
                        ),
                        if (result.hasDetection &&
                            result.topPredictions.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _TopPredictionsCard(result: result),
                        ],
                        const SizedBox(height: 20),
                        if (result.hasDetection)
                          GestureDetector(
                            onTap: () =>
                                context.push('/disease-details', extra: result),
                            child: _PrimaryButton(
                              label: lang.t('scan.viewDetails'),
                              icon: Icons.info_outline,
                            ),
                          ),
                        if (result.hasDetection) const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => context.go('/scan'),
                          child: _SecondaryButton(
                            label: lang.t('scan.scanAnother'),
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

  ScanResult? _resolveResult(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    if (extra is ScanResult) {
      return extra;
    }
    final scans = context.watch<ScanHistoryProvider>().scans;
    return scans.isEmpty ? null : scans.first;
  }

  String _severityLabel(LanguageProvider lang, String severity) {
    switch (severity) {
      case 'high':
        return lang.t('disease.high');
      case 'medium':
        return lang.t('disease.medium');
      default:
        return lang.t('disease.low');
    }
  }

  Color _severityColor(String? severity) {
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.lang});

  final LanguageProvider lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.image_search_outlined,
            size: 64,
            color: Color(0xFF9E9E9E),
          ),
          const SizedBox(height: 12),
          Text(
            lang.t('scan.noResults'),
            style: const TextStyle(
              color: Color(0xFF424242),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: double.infinity,
          height: 220,
          child: result.isVideo ? _buildVideoPlaceholder() : _buildImage(),
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      color: const Color(0xFF102A43),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_rounded, size: 72, color: Colors.white),
          SizedBox(height: 12),
          Text(
            'Video scan uploaded',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final localFile = File(result.imagePath);
    if (localFile.existsSync()) {
      return Image.file(localFile, fit: BoxFit.cover);
    }
    if ((result.remoteMediaUrl ?? '').isNotEmpty) {
      return Image.network(
        result.remoteMediaUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackImage(),
      );
    }
    return _fallbackImage();
  }

  Widget _fallbackImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x334CAF50), Color(0x332E7D32)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.local_florist_rounded,
          size: 64,
          color: Color(0xFF2E7D32),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.result,
    required this.lang,
    required this.severityColor,
    required this.severityLabel,
  });

  final ScanResult result;
  final LanguageProvider lang;
  final Color severityColor;
  final String severityLabel;

  @override
  Widget build(BuildContext context) {
    final confidencePercent = (result.confidence * 100).round();
    final scannedAt = result.scannedAt.toLocal().toString().replaceFirst(
      '.000',
      '',
    );

    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.hasDetection
                          ? (result.isHealthy
                                ? lang.t('scan.healthy')
                                : result.diseaseNameEn)
                          : result.diseaseNameEn,
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (result.scientificName.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        result.scientificName,
                        style: const TextStyle(
                          color: Color(0xFF616161),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                result.isHealthy
                    ? Icons.check_circle
                    : (result.isVideo
                          ? Icons.video_file_rounded
                          : Icons.error_outline),
                color: severityColor,
                size: 30,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoRow(
            label: 'Crop',
            value: result.cropType.isEmpty ? 'tomato' : result.cropType,
          ),
          _InfoRow(label: 'Media', value: result.mediaType),
          _InfoRow(label: 'Status', value: result.status),
          _InfoRow(label: 'Scanned At', value: scannedAt),
          if (result.modelVersion.isNotEmpty)
            _InfoRow(label: 'Model', value: result.modelVersion),
          if (result.hasDetection) ...[
            const SizedBox(height: 12),
            _MetricBar(
              label: lang.t('scan.severity'),
              value: severityLabel,
              percent: _severityPercent(result.severity),
              color: severityColor,
            ),
            const SizedBox(height: 14),
            _MetricBar(
              label: lang.t('scan.confidence'),
              value: '$confidencePercent${lang.t('units.percent')}',
              percent: result.confidence.clamp(0, 1).toDouble(),
              color: const Color(0xFF4CAF50),
            ),
            const SizedBox(height: 18),
            _InfoRow(label: 'Risk Level', value: result.riskLevel),
          ] else ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                result.isVideo
                    ? (result.isStoredRemotely
                          ? 'The video file has been stored successfully in cloud storage. The current demo only runs tomato classification on images.'
                          : 'The video file was stored locally on the backend because cloud storage is not enabled right now.')
                    : 'This scan was uploaded, but no model result is available yet.',
                style: const TextStyle(
                  color: Color(0xFF1E3A5F),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (result.recommendation.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.t('disease.recommendedAction'),
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    result.recommendation,
                    style: const TextStyle(
                      color: Color(0xFF424242),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _severityPercent(String severity) {
    switch (severity) {
      case 'high':
        return 0.85;
      case 'medium':
        return 0.6;
      default:
        return 0.25;
    }
  }
}

class _TopPredictionsCard extends StatelessWidget {
  const _TopPredictionsCard({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text(
            'Top Predictions',
            style: TextStyle(
              color: Color(0xFF2E7D32),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...result.topPredictions.map((prediction) {
            final percent = (prediction.confidence * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                            color: Color(0xFF424242),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: prediction.confidence.clamp(0, 1).toDouble(),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F1F1),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF4CAF50),
                      ),
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
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF757575),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF424242), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });

  final String label;
  final String value;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFF424242), fontSize: 16),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: const Color(0xFFF1F1F1),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50), width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF4CAF50),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
