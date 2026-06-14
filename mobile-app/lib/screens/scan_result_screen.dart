import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/api_client.dart';
import 'package:agrilens/core/app_config.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/widgets/post_scan_community_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen (StatefulWidget so we can fetch the AI report lazily)
// ─────────────────────────────────────────────────────────────────────────────

class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({super.key});

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  Map<String, dynamic>? _report;
  bool _reportLoading = false;
  bool _reportFailed = false;
  bool _reportExpanded = false; // only shown after button tap

  ScanResult? _resolveResult() {
    final extra = GoRouterState.of(context).extra;
    if (extra is ScanResult) return extra;
    final scans = context.read<ScanHistoryProvider>().scans;
    return scans.isEmpty ? null : scans.first;
  }

  Future<void> _fetchReport() async {
    final result = _resolveResult();
    if (result == null || !result.hasDetection || result.isHealthy) return;

    setState(() {
      _reportLoading = true;
      _reportFailed = false;
    });

    final lang = context.read<LanguageProvider>();
    try {
      final res = await ApiClient().post(
        '/api/disease-report',
        auth: false,
        body: {
          'disease': result.diseaseNameEn,
          'crop_type': result.cropType.isEmpty ? 'unknown' : result.cropType,
          'severity': result.severity,
          'confidence': result.confidence,
          'scientific_name': result.scientificName,
          'lang': lang.isRTL ? 'ar' : 'en',
        },
      );
      if (!mounted) return;
      final report = (res['data'] as Map<String, dynamic>?)?['report'];
      setState(() {
        _report = report as Map<String, dynamic>?;
        _reportLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reportLoading = false;
        _reportFailed = true;
      });
    }
  }

  /// Called when the user taps "View Full Details".
  /// First tap: expand + fetch (if not already fetched).
  /// Second tap: collapse.
  void _toggleReport() {
    if (!_reportExpanded) {
      setState(() => _reportExpanded = true);
      if (_report == null && !_reportFailed && !_reportLoading) {
        _fetchReport();
      }
    } else {
      setState(() => _reportExpanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final result = _resolveResult();
    final severityColor = _severityColor(result?.severity);
    final severityLabel = _severityLabel(lang, result?.severity ?? 'none');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
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
                  icon: const Icon(Icons.arrow_back, size: 28, color: Color(0xFF424242)),
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

          // ── Body ─────────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: result == null
                  ? _EmptyState(lang: lang)
                  : Column(
                      children: [
                        // 1. Image / Grad-CAM
                        _MediaPreview(result: result),
                        if (result.gradcamOverlay != null) ...[
                          const SizedBox(height: 16),
                          _GradCamCard(result: result, lang: lang),
                        ],

                        // 2. Summary (disease name, badges, bars)
                        const SizedBox(height: 16),
                        _SummaryCard(
                          result: result,
                          lang: lang,
                          severityColor: severityColor,
                          severityLabel: severityLabel,
                        ),

                        // 3. Top predictions
                        if (result.hasDetection && result.topPredictions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _TopPredictionsCard(result: result),
                        ],

                        // 4. "View Full Details" toggle button (only for diseases)
                        if (result.hasDetection && !result.isHealthy) ...[
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: _toggleReport,
                            child: _DetailsToggleButton(
                              expanded: _reportExpanded,
                              loading: _reportLoading,
                              label: lang.t('scan.viewDetails'),
                              lang: lang,
                            ),
                          ),
                        ],

                        // 5. AI Report (shown when expanded)
                        if (result.hasDetection && !result.isHealthy && _reportExpanded) ...[
                          const SizedBox(height: 16),
                          _AiReportCard(
                            report: _report,
                            loading: _reportLoading,
                            failed: _reportFailed,
                            onRetry: _fetchReport,
                            lang: lang,
                          ),
                        ],

                        // 6. Community suggestions (after disease detected)
                        if (result.hasDetection) ...[
                          const SizedBox(height: 8),
                          PostScanCommunityCard(
                            cropType: result.cropType,
                            disease: result.isHealthy
                                ? ''
                                : result.diseaseNameEn,
                          ),
                        ],

                        // 7. Scan Again button
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => context.go('/scan'),
                          child: _PrimaryButton(
                            label: lang.t('scan.scanAnother'),
                            icon: Icons.camera_alt_outlined,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
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

// ─────────────────────────────────────────────────────────────────────────────
// Toggle button for "View Full Details" / "Hide Details"
// ─────────────────────────────────────────────────────────────────────────────

class _DetailsToggleButton extends StatelessWidget {
  const _DetailsToggleButton({
    required this.expanded,
    required this.loading,
    required this.label,
    required this.lang,
  });

  final bool expanded;
  final bool loading;
  final String label;
  final LanguageProvider lang;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: expanded ? const Color(0xFF2E7D32) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF4CAF50),
              ),
            )
          else
            Icon(
              expanded ? Icons.expand_less : Icons.info_outline,
              size: 20,
              color: expanded ? Colors.white : const Color(0xFF4CAF50),
            ),
          const SizedBox(width: 8),
          Text(
            expanded ? (lang.isRTL ? 'إخفاء التفاصيل' : 'Hide Details') : label,
            style: TextStyle(
              color: expanded ? Colors.white : const Color(0xFF4CAF50),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Report Card
// ─────────────────────────────────────────────────────────────────────────────

class _AiReportCard extends StatelessWidget {
  const _AiReportCard({
    required this.report,
    required this.loading,
    required this.failed,
    required this.onRetry,
    required this.lang,
  });

  final Map<String, dynamic>? report;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;
  final LanguageProvider lang;

  @override
  Widget build(BuildContext context) {
    final isAr = lang.isRTL;

    if (loading) {
      return _card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              const CircularProgressIndicator(color: Color(0xFF2E7D32)),
              const SizedBox(height: 16),
              Text(
                isAr ? 'جارٍ إنشاء التقرير…' : 'Generating AI report…',
                style: const TextStyle(color: Color(0xFF757575), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (failed || report == null) {
      return _card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              const Icon(Icons.wifi_off_outlined, size: 40, color: Color(0xFFBDBDBD)),
              const SizedBox(height: 12),
              Text(
                isAr ? 'تعذّر تحميل التقرير' : 'Could not load AI report',
                style: const TextStyle(color: Color(0xFF616161), fontSize: 15),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(isAr ? 'إعادة المحاولة' : 'Retry'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF2E7D32)),
              ),
            ],
          ),
        ),
      );
    }

    final r = report!;
    final urgencyLevel = r['urgency_level']?.toString() ?? 'medium';
    final urgencyColor = urgencyLevel == 'high'
        ? const Color(0xFFD32F2F)
        : urgencyLevel == 'medium'
            ? const Color(0xFFF57C00)
            : const Color(0xFF388E3C);
    final urgencyBg = urgencyLevel == 'high'
        ? const Color(0xFFFFEBEE)
        : urgencyLevel == 'medium'
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFE8F5E9);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card title
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Color(0xFF2E7D32), size: 22),
              const SizedBox(width: 8),
              Text(
                isAr ? 'تقرير مرض الذكاء الاصطناعي' : 'AI Disease Report',
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Urgency banner ─────────────────────────────────────────────────
          if (r['urgency_label'] != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: urgencyBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: urgencyColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    urgencyLevel == 'high'
                        ? Icons.warning_amber_rounded
                        : urgencyLevel == 'medium'
                            ? Icons.access_time_rounded
                            : Icons.check_circle_outline,
                    color: urgencyColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r['urgency_label'].toString(),
                      style: TextStyle(
                        color: urgencyColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── What is it ─────────────────────────────────────────────────────
          if (r['what_is_it'] != null) ...[
            const SizedBox(height: 16),
            _SectionTitle(icon: Icons.info_outline, label: isAr ? 'ما هذا المرض؟' : 'What is this disease?'),
            const SizedBox(height: 8),
            Text(
              r['what_is_it'].toString(),
              style: const TextStyle(color: Color(0xFF424242), fontSize: 14, height: 1.6),
            ),
          ],

          // ── Estimated impact ────────────────────────────────────────────────
          if (r['estimated_impact'] != null) ...[
            const SizedBox(height: 16),
            _SectionTitle(icon: Icons.trending_down, label: isAr ? 'التأثير المتوقع على المحصول' : 'Estimated crop impact'),
            const SizedBox(height: 8),
            _HighlightBox(
              text: r['estimated_impact'].toString(),
              color: urgencyColor,
              bgColor: urgencyBg,
            ),
          ],

          // ── Symptoms ────────────────────────────────────────────────────────
          if (_asList(r['symptoms']).isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(icon: Icons.search, label: isAr ? 'الأعراض للتحقق' : 'Symptoms to verify'),
            const SizedBox(height: 8),
            ..._asList(r['symptoms']).map(
              (s) => _BulletRow(text: s, icon: Icons.circle, iconColor: const Color(0xFF9E9E9E)),
            ),
          ],

          // ── How it spreads ──────────────────────────────────────────────────
          if (r['how_spreads'] != null) ...[
            const SizedBox(height: 16),
            _SectionTitle(icon: Icons.air, label: isAr ? 'كيف ينتشر' : 'How it spreads'),
            const SizedBox(height: 8),
            Text(
              r['how_spreads'].toString(),
              style: const TextStyle(color: Color(0xFF616161), fontSize: 14, height: 1.5),
            ),
          ],

          // ── Immediate actions ───────────────────────────────────────────────
          if (_asList(r['immediate_actions']).isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(icon: Icons.bolt, label: isAr ? 'الإجراءات الفورية (اليوم)' : 'Immediate actions (today)'),
            const SizedBox(height: 8),
            ..._asList(r['immediate_actions']).asMap().entries.map(
              (e) => _NumberedRow(index: e.key + 1, text: e.value, color: urgencyColor),
            ),
          ],

          // ── Treatment ──────────────────────────────────────────────────────
          const SizedBox(height: 16),
          _SectionTitle(icon: Icons.local_pharmacy_outlined, label: isAr ? 'خيارات العلاج' : 'Treatment options'),
          const SizedBox(height: 8),
          if (_asList(r['treatment_chemical']).isNotEmpty) ...[
            _SubLabel(text: isAr ? '🧪 كيميائي' : '🧪 Chemical'),
            const SizedBox(height: 4),
            ..._asList(r['treatment_chemical']).map(
              (s) => _BulletRow(text: s, icon: Icons.circle, iconColor: const Color(0xFF1976D2)),
            ),
            const SizedBox(height: 8),
          ],
          if (_asList(r['treatment_organic']).isNotEmpty) ...[
            _SubLabel(text: isAr ? '🌿 عضوي' : '🌿 Organic'),
            const SizedBox(height: 4),
            ..._asList(r['treatment_organic']).map(
              (s) => _BulletRow(text: s, icon: Icons.circle, iconColor: const Color(0xFF388E3C)),
            ),
          ],

          // ── Prevention ─────────────────────────────────────────────────────
          if (_asList(r['prevention']).isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(icon: Icons.shield_outlined, label: isAr ? 'الوقاية' : 'Prevention'),
            const SizedBox(height: 8),
            ..._asList(r['prevention']).map(
              (s) => _BulletRow(text: s, icon: Icons.check_circle_outline, iconColor: const Color(0xFF4CAF50)),
            ),
          ],

          // ── Confidence note ─────────────────────────────────────────────────
          if (r['confidence_note'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: Color(0xFFFFA000), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r['confidence_note'].toString(),
                      style: const TextStyle(
                        color: Color(0xFF616161),
                        fontSize: 13,
                        height: 1.5,
                      ),
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

  List<String> _asList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String && value.isNotEmpty) return [value];
    return [];
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets inside the report card
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF2E7D32),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SubLabel extends StatelessWidget {
  const _SubLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF424242),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text, required this.icon, required this.iconColor});
  final String text;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(icon, size: 8, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF424242), fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberedRow extends StatelessWidget {
  const _NumberedRow({required this.index, required this.text, required this.color});
  final int index;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: const TextStyle(color: Color(0xFF424242), fontSize: 14, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightBox extends StatelessWidget {
  const _HighlightBox({required this.text, required this.color, required this.bgColor});
  final String text;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Existing widgets (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

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
          const Icon(Icons.image_search_outlined, size: 64, color: Color(0xFF9E9E9E)),
          const SizedBox(height: 12),
          Text(
            lang.t('scan.noResults'),
            style: const TextStyle(color: Color(0xFF424242), fontSize: 18, fontWeight: FontWeight.w600),
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
          Text('Video scan uploaded',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildImage() {
    // Cached bytes (freshly scanned image — instant, no network)
    if (result.localImageBytes != null) {
      return Image.memory(result.localImageBytes!, fit: BoxFit.cover);
    }
    if (!kIsWeb) {
      final localFile = io.File(result.imagePath);
      if (localFile.existsSync()) return Image.file(localFile, fit: BoxFit.cover);
    }
    final url = (result.remoteMediaUrl?.isNotEmpty == true)
        ? result.remoteMediaUrl!
        : (result.imagePath.isNotEmpty
            ? AppConfig.resolveMediaUrl(result.imagePath)
            : '');
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackImage(),
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
        child: Icon(Icons.local_florist_rounded, size: 64, color: Color(0xFF2E7D32)),
      ),
    );
  }
}

class _GradCamCard extends StatelessWidget {
  const _GradCamCard({required this.result, required this.lang});
  final ScanResult result;
  final LanguageProvider lang;

  @override
  Widget build(BuildContext context) {
    final isAr = lang.isRTL;
    final overlayBytes = base64Decode(result.gradcamOverlay!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.visibility_outlined, color: Color(0xFF2E7D32), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAr
                      ? 'لماذا صنّف الذكاء الاصطناعي هذه النتيجة؟'
                      : 'Why did the AI flag this?',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Stacked view: original photo + RGBA heatmap overlay ────────────
          // The heatmap is fully transparent where the plant is healthy and
          // orange/red where the model detected disease — so the real photo
          // shows through everywhere except the flagged region.
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Layer 1 — original leaf photo (full-size, fills the card)
                  _buildLeafPhoto(),
                  // Layer 2 — transparent RGBA heatmap: opaque only at hotspot
                  Image.memory(overlayBytes, fit: BoxFit.cover),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          // ── Caption ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔴 ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Text(
                    isAr
                        ? 'المناطق الحمراء / الصفراء تُظهر ما ركّز عليه النموذج للوصول إلى هذا التشخيص.'
                        : 'Red / yellow areas show what the model focused on to reach this diagnosis.',
                    style: const TextStyle(
                      color: Color(0xFF6D4C41),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the original leaf photo layer.
  ///
  /// Priority:
  ///   1. localImageBytes — bytes cached at scan-creation time (instant, no
  ///      network needed; always present for a freshly scanned image).
  ///   2. Local file on disk (mobile only).
  ///   3. Remote URL (remoteMediaUrl or imagePath resolved via AppConfig).
  ///   4. Solid green placeholder while loading / on error.
  Widget _buildLeafPhoto() {
    // ── 1. Cached bytes (instant, preferred) ─────────────────────────────────
    if (result.localImageBytes != null) {
      return Image.memory(result.localImageBytes!, fit: BoxFit.cover);
    }

    // ── 2. Local file (mobile) ────────────────────────────────────────────────
    if (!kIsWeb) {
      final localFile = io.File(result.imagePath);
      if (localFile.existsSync()) {
        return Image.file(localFile, fit: BoxFit.cover);
      }
    }

    // ── 3. Remote URL ─────────────────────────────────────────────────────────
    // Prefer remoteMediaUrl; fall back to resolving imagePath in case it is a
    // relative path like '/uploads/...' that AppConfig can turn into a full URL.
    final url = (result.remoteMediaUrl?.isNotEmpty == true)
        ? result.remoteMediaUrl!
        : (result.imagePath.isNotEmpty
            ? AppConfig.resolveMediaUrl(result.imagePath)
            : '');

    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        frameBuilder: (_, child, frame, __) =>
            frame == null ? _placeholder() : child,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF2E7D32),
      child: const Center(
        child: Icon(
          Icons.local_florist_rounded,
          size: 56,
          color: Color(0x884CAF50),
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
    final scannedAt = result.scannedAt.toLocal().toString().replaceFirst('.000', '');

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
                          ? (result.isHealthy ? lang.t('scan.healthy') : result.diseaseNameEn)
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
                        style: const TextStyle(color: Color(0xFF616161), fontSize: 15),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                result.isHealthy
                    ? Icons.check_circle
                    : (result.isVideo ? Icons.video_file_rounded : Icons.error_outline),
                color: severityColor,
                size: 30,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoRow(label: 'Crop', value: result.cropType.isEmpty ? 'tomato' : result.cropType),
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
            const SizedBox(height: 14),
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
                        ? 'The video file has been stored in cloud storage. Video analysis is not available in this demo.'
                        : 'The video file was stored locally. Cloud storage is not enabled right now.')
                    : 'This scan was uploaded, but no model result is available yet.',
                style: const TextStyle(color: Color(0xFF1E3A5F), fontSize: 15, height: 1.4),
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
          const Text('Top Predictions',
              style: TextStyle(color: Color(0xFF2E7D32), fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ...result.topPredictions.map((p) {
            final percent = (p.confidence * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.disease.isEmpty ? p.label : p.disease,
                          style: const TextStyle(
                              color: Color(0xFF424242), fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text('$percent%',
                          style: const TextStyle(
                              color: Color(0xFF2E7D32), fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: p.confidence.clamp(0, 1).toDouble(),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F1F1),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF4CAF50)),
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
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF757575), fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Color(0xFF424242), fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar(
      {required this.label, required this.value, required this.percent, required this.color});
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
            Text(label, style: const TextStyle(color: Color(0xFF424242), fontSize: 16)),
            Text(value,
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
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
      padding: const EdgeInsets.symmetric(vertical: 18),
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
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50), width: 2),
      ),
      child: Text(label,
          style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 17, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
    );
  }
}
