import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/api_client.dart';
import 'package:agrilens/core/app_config.dart';
import 'package:agrilens/core/crop_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/user_provider.dart';
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
  String? _reportLang; // language code used when the report was last fetched

  @override
  void initState() {
    super.initState();
    // When navigating here from a notification tap, `extra` is a scan ID string.
    // History may not be loaded yet, so trigger a refresh and rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final extra = GoRouterState.of(context).extra;
      if (extra is String && extra.isNotEmpty) {
        context.read<ScanHistoryProvider>().loadScans().then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_reportExpanded || _report == null) return;
    final currentLang = context.read<LanguageProvider>().isRTL ? 'ar' : 'en';
    if (_reportLang != null && _reportLang != currentLang) {
      setState(() {
        _report = null;
        _reportFailed = false;
        _reportLang = null;
      });
      _fetchReport();
    }
  }

  ScanResult? _resolveResult() {
    final extra = GoRouterState.of(context).extra;
    if (extra is ScanResult) return extra;
    final scans = context.read<ScanHistoryProvider>().scans;
    // Notification deep-link: extra is the scan ID string.
    if (extra is String && extra.isNotEmpty) {
      try {
        return scans.firstWhere((s) => s.id == extra);
      } catch (_) {
        return null; // still loading — initState will trigger a rebuild
      }
    }
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
        _reportLang = lang.isRTL ? 'ar' : 'en';
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
    final user = context.watch<UserProvider>();
    final result = _resolveResult();
    final severityColor = _severityColor(result?.severity);
    final severityLabel = _severityLabel(lang, result?.severity ?? 'none');

    // FREE users get a concise 2-section report.
    // PREMIUM and PROFESSIONAL get the full detailed report.
    final isPaidPlan =
        user.plan == 'premium' || user.plan == 'professional';

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
                        // AI disclaimer banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 16, color: Color(0xFFB45309)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lang.isRTL
                                      ? 'هذه النتائج مُولَّدة بالذكاء الاصطناعي. للقرارات الزراعية الحرجة، يُرجى استشارة مهندس زراعي متخصص.'
                                      : 'AI-generated results. For critical crop decisions, consult a certified agronomist.',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF92400E),
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 1. Grad-CAM (base64 from live result OR URL from history)
                        if (result.gradcamOverlay != null ||
                            (result.gradcamUrl != null && !result.isHealthy)) ...[
                          _GradCamCard(result: result, lang: lang),
                          const SizedBox(height: 16),
                        ],
                        if (result.isVideo && result.selectedFrames.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _SelectedVideoFramesCard(result: result),
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
                            isPaidPlan: isPaidPlan,
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
                          onTap: () => context.go('/crop-select'),
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
    required this.isPaidPlan,
  });

  final Map<String, dynamic>? report;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;
  final LanguageProvider lang;
  /// true = Premium or Professional (full report); false = Free (concise only)
  final bool isPaidPlan;

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

    // ── FREE plan: concise report (description + basic treatment only) ────────
    if (!isPaidPlan) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Color(0xFF2E7D32), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAr ? 'وصف المرض' : 'Disease Overview',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Basic disease description
            if (r['what_is_it'] != null) ...[
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isAr ? 'ما هذا المرض؟' : 'What is this disease?',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Show only first 2 sentences for free users
              Text(
                _truncate(r['what_is_it'].toString(), 2),
                style: const TextStyle(color: Color(0xFF424242), fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 16),
            ],

            // Basic treatment (organic only, first item)
            if (_asList(r['treatment_organic']).isNotEmpty) ...[
              _SectionTitle(
                  icon: Icons.local_pharmacy_outlined,
                  label: isAr ? 'توصية العلاج الأساسية' : 'Basic Treatment Recommendation'),
              const SizedBox(height: 8),
              _BulletRow(
                text: _asList(r['treatment_organic']).first,
                icon: Icons.circle,
                iconColor: const Color(0xFF388E3C),
              ),
              const SizedBox(height: 16),
            ],

            // Upgrade prompt
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, color: Color(0xFF2E7D32), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAr
                              ? 'التقرير الكامل متاح لمشتركي بريميوم والاحترافي'
                              : 'Full report available on Premium & Professional',
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAr
                        ? 'يشمل: تقييم الشدة، الأعراض والأسباب، الجدول الزمني للتعافي، التدابير الوقائية، وأكثر.'
                        : 'Includes: severity assessment, symptoms & causes, recovery timeline, preventive measures, and more.',
                    style: const TextStyle(color: Color(0xFF616161), fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── PREMIUM / PROFESSIONAL: full detailed report ──────────────────────────
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card title
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Color(0xFF2E7D32), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAr ? 'تقرير مرض الذكاء الاصطناعي' : 'AI Disease Report',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Urgency banner ───────────────────────────────────────────────────
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

          // ── What is it ───────────────────────────────────────────────────────
          if (r['what_is_it'] != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, size: 18, color: Color(0xFF2E7D32)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isAr ? 'ما هذا المرض؟' : 'What is this disease?',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (r['pathogen_type'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF4CAF50)),
                    ),
                    child: Text(
                      r['pathogen_type'].toString(),
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              r['what_is_it'].toString(),
              style: const TextStyle(color: Color(0xFF424242), fontSize: 14, height: 1.6),
            ),
          ],

          // ── Estimated impact ─────────────────────────────────────────────────
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

          // ── Favorable conditions ─────────────────────────────────────────────
          if (r['favorable_conditions'] != null) ...[
            const SizedBox(height: 16),
            _SectionTitle(icon: Icons.thermostat_outlined, label: isAr ? 'الظروف المناسبة للانتشار' : 'Conditions that favour spread'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCE93D8)),
              ),
              child: Text(
                r['favorable_conditions'].toString(),
                style: const TextStyle(color: Color(0xFF4A148C), fontSize: 13, height: 1.5),
              ),
            ),
          ],

          // ── Economic threshold ───────────────────────────────────────────────
          if (r['economic_threshold'] != null) ...[
            const SizedBox(height: 16),
            _SectionTitle(icon: Icons.monetization_on_outlined, label: isAr ? 'العتبة الاقتصادية للتدخل' : 'Economic treatment threshold'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFCC02)),
              ),
              child: Text(
                r['economic_threshold'].toString(),
                style: const TextStyle(color: Color(0xFF5D4037), fontSize: 13, height: 1.5),
              ),
            ),
          ],

          // ── Symptoms ─────────────────────────────────────────────────────────
          if (_asList(r['symptoms']).isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(icon: Icons.search, label: isAr ? 'الأعراض للتحقق' : 'Symptoms to verify'),
            const SizedBox(height: 8),
            ..._asList(r['symptoms']).map(
              (s) => _BulletRow(text: s, icon: Icons.circle, iconColor: const Color(0xFF9E9E9E)),
            ),
          ],

          // ── Look-alike diseases ──────────────────────────────────────────────
          if (_asList(r['look_alike_diseases']).isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(icon: Icons.compare_arrows_outlined, label: isAr ? 'أمراض مشابهة — كيف تميّز؟' : 'Similar diseases — how to tell apart'),
            const SizedBox(height: 8),
            ..._asList(r['look_alike_diseases']).map(
              (s) => _BulletRow(text: s, icon: Icons.help_outline, iconColor: const Color(0xFF7B1FA2)),
            ),
          ],

          // ── How it spreads ───────────────────────────────────────────────────
          if (r['how_spreads'] != null) ...[
            const SizedBox(height: 16),
            _SectionTitle(icon: Icons.air, label: isAr ? 'كيف ينتشر' : 'How it spreads'),
            const SizedBox(height: 8),
            Text(
              r['how_spreads'].toString(),
              style: const TextStyle(color: Color(0xFF616161), fontSize: 14, height: 1.5),
            ),
          ],

          // ── Immediate actions ────────────────────────────────────────────────
          if (_asList(r['immediate_actions']).isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(icon: Icons.bolt, label: isAr ? 'الإجراءات الفورية (اليوم)' : 'Immediate actions (today)'),
            const SizedBox(height: 8),
            ..._asList(r['immediate_actions']).asMap().entries.map(
              (e) => _NumberedRow(index: e.key + 1, text: e.value, color: urgencyColor),
            ),
          ],

          // ── Treatment ────────────────────────────────────────────────────────
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

          // ── When to apply ────────────────────────────────────────────────────
          if (r['when_to_apply'] != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.schedule, color: Color(0xFF1565C0), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (isAr ? 'توقيت التطبيق: ' : 'When to apply: ') +
                          r['when_to_apply'].toString(),
                      style: const TextStyle(color: Color(0xFF0D47A1), fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Prevention ───────────────────────────────────────────────────────
          if (_asList(r['prevention']).isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(icon: Icons.shield_outlined, label: isAr ? 'الوقاية' : 'Prevention'),
            const SizedBox(height: 8),
            ..._asList(r['prevention']).map(
              (s) => _BulletRow(text: s, icon: Icons.check_circle_outline, iconColor: const Color(0xFF4CAF50)),
            ),
          ],

          // ── Recovery timeline ─────────────────────────────────────────────────
          if (r['recovery_timeline'] != null) ...[
            const SizedBox(height: 16),
            _SectionTitle(
              icon: Icons.timeline_rounded,
              label: isAr ? 'الجدول الزمني للتعافي' : 'Recovery timeline',
            ),
            const SizedBox(height: 10),
            _RecoveryTimeline(timeline: r['recovery_timeline'], isAr: isAr),
          ],

          // ── Confidence note ──────────────────────────────────────────────────
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
                      style: const TextStyle(color: Color(0xFF616161), fontSize: 13, height: 1.5),
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

  /// Returns the first [n] sentences of [text].
  String _truncate(String text, int sentences) {
    final matches = RegExp(r'[^.!?]+[.!?]+').allMatches(text).take(sentences);
    if (matches.isEmpty) return text;
    return matches.map((m) => m.group(0)!).join(' ').trim();
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

// ─────────────────────────────────────────────────────────────────────────────
// Recovery Timeline Widget
// ─────────────────────────────────────────────────────────────────────────────

class _RecoveryTimeline extends StatelessWidget {
  const _RecoveryTimeline({required this.timeline, required this.isAr});
  final dynamic timeline;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    // timeline may be a List of step objects or a plain String
    if (timeline is List) {
      final steps = (timeline as List).cast<dynamic>();
      return Column(
        children: steps.asMap().entries.map((e) {
          final step = e.value;
          final isLast = e.key == steps.length - 1;
          final label = step is Map
              ? (step['label']?.toString() ?? step['phase']?.toString() ?? 'Step ${e.key + 1}')
              : step.toString();
          final duration = step is Map ? step['duration']?.toString() : null;
          final detail = step is Map ? step['detail']?.toString() : null;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Container(width: 2, height: 36, color: const Color(0xFFBDBDBD)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (duration != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                duration,
                                style: const TextStyle(
                                  color: Color(0xFF388E3C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          detail,
                          style: const TextStyle(
                            color: Color(0xFF757575),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      );
    }
    // Plain text fallback
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
      ),
      child: Text(
        timeline.toString(),
        style: const TextStyle(
          color: Color(0xFF2E7D32),
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}

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
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
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

class _NoDetectionBanner extends StatelessWidget {
  const _NoDetectionBanner({required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final isAr = lang.isRTL;
    final isInvalid = result.status == 'invalid_image';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isInvalid ? const Color(0xFFFFEBEE) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: isInvalid
          ? Column(
              children: [
                const Icon(Icons.no_photography_outlined, size: 40, color: Color(0xFFE53935)),
                const SizedBox(height: 10),
                Text(
                  isAr
                      ? 'لا تبدو هذه الصورة أنها تحتوي على نبات أو ورقة.'
                      : 'This image does not appear to contain a plant or leaf.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB71C1C),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isAr
                      ? 'يرجى التقاط صورة واضحة ومقربة لورقة نبات أو منطقة مصابة.'
                      : 'Please upload a clear, close-up photo of a plant leaf or affected area.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF616161), fontSize: 14, height: 1.4),
                ),
              ],
            )
          : Text(
              result.isVideo
                  ? (result.isStoredRemotely
                      ? 'The video file has been stored in cloud storage. Video analysis is not available in this demo.'
                      : 'The video file was stored locally. Cloud storage is not enabled right now.')
                  : (isAr
                      ? 'تم رفع الصورة، لكن لم تتوفر نتيجة بعد.'
                      : 'This scan was uploaded, but no model result is available yet.'),
              style: const TextStyle(color: Color(0xFF1E3A5F), fontSize: 15, height: 1.4),
            ),
    );
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

// ignore: unused_element
class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
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
          child: result.isVideo ? _buildVideoPlaceholder(lang) : _buildImage(),
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder(LanguageProvider lang) {
    if (result.selectedFrames.isNotEmpty) {
      final firstFrame = result.selectedFrames.first;
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            firstFrame.displayUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallbackImage(),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    lang.isRTL ? 'فحص بالفيديو' : 'Video scan',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      color: const Color(0xFF102A43),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_rounded, size: 72, color: Colors.white),
          const SizedBox(height: 12),
          Text(lang.isRTL ? 'تم رفع فحص الفيديو' : 'Video scan uploaded',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
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
        errorBuilder: (_, _, _) => _fallbackImage(),
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
class _SelectedVideoFramesCard extends StatelessWidget {
  const _SelectedVideoFramesCard({required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final frames = result.selectedFrames;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, color: Color(0xFF2E7D32), size: 20),
              const SizedBox(width: 8),
              Text(
                lang.isRTL ? 'الإطارات المحللة المختارة' : 'Selected analyzed frames',
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: frames.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
            itemBuilder: (context, index) {
              return _SelectedVideoFrameTile(frame: frames[index]);
            },
          ),
        ],
      ),
    );
  }
}

class _SelectedVideoFrameTile extends StatelessWidget {
  const _SelectedVideoFrameTile({required this.frame});
  final SelectedVideoFrame frame;

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    final showGradcam = !frame.isHealthy && frame.hasGradcam;
    final imageUrl = showGradcam ? frame.gradcamUrl! : frame.displayUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFFF5F5F5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.image_not_supported_outlined, color: Color(0xFF9E9E9E)),
                    ),
                  ),
                  if (showGradcam)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _FrameBadge(label: 'Grad-CAM', color: const Color(0xFFD84315)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    frame.isHealthy ? (lang.isRTL ? 'إطار صحي' : 'Healthy frame') : frame.disease,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF424242),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lang.localizeNum((frame.confidence * 100).round())}${lang.isRTL ? "% ثقة" : "% confidence"}',
                    style: const TextStyle(color: Color(0xFF757575), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameBadge extends StatelessWidget {
  const _FrameBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
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
    // Prefer the in-memory base64 overlay (fresh scan); fall back to the
    // persistent URL stored after the first detection.
    final hasOverlay = result.gradcamOverlay != null;
    final overlayBytes = hasOverlay ? base64Decode(result.gradcamOverlay!) : null;

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

          // ── Grad-CAM visualisation ─────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: hasOverlay
                  // Fresh scan: stack original photo + transparent RGBA overlay.
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildLeafPhoto(),
                        Image.memory(overlayBytes!, fit: BoxFit.cover),
                      ],
                    )
                  // History: show the composited image uploaded to storage.
                  : Image.network(
                      result.gradcamUrl!,
                      fit: BoxFit.cover,
                      headers: const {'ngrok-skip-browser-warning': 'true'},
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: Color(0xFF9E9E9E)),
                      ),
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
        frameBuilder: (_, child, frame, _) =>
            frame == null ? _placeholder() : child,
        errorBuilder: (_, _, _) => _placeholder(),
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
    final crops = context.read<CropProvider>();
    final confidencePercent = (result.confidence * 100).round();
    final dt = result.scannedAt.toLocal();
    String pad(int n) => lang.localizeDigits(n.toString().padLeft(2, '0'));
    final scannedAt = lang.isRTL
        ? '${lang.localizeNum(dt.day)}/${lang.localizeNum(dt.month)}/${lang.localizeNum(dt.year)}  ${pad(dt.hour)}:${pad(dt.minute)}'
        : '${dt.month}/${dt.day}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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
                          ? (result.isHealthy ? lang.t('scan.healthy') : (lang.isRTL ? result.diseaseNameAr : result.diseaseNameEn))
                          : (lang.isRTL ? result.diseaseNameAr : result.diseaseNameEn),
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
          _InfoRow(
            label: lang.isRTL ? 'المحصول' : 'Crop',
            value: crops.getLabel(result.cropType.isEmpty ? 'tomato' : result.cropType, isRTL: lang.isRTL),
          ),
          _InfoRow(
            label: lang.isRTL ? 'الوسيط' : 'Media',
            value: result.mediaType == 'video' ? lang.t('scan.mediaVideo') : lang.t('scan.mediaPhoto'),
          ),
          _InfoRow(label: lang.isRTL ? 'الحالة' : 'Status', value: _localizedStatus(result.status, lang)),
          _InfoRow(label: lang.isRTL ? 'وقت الفحص' : 'Scanned At', value: scannedAt),
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
              value: '${lang.localizeNum(confidencePercent)}${lang.t('units.percent')}',
              percent: result.confidence.clamp(0, 1).toDouble(),
              color: const Color(0xFF4CAF50),
            ),
            const SizedBox(height: 14),
            _InfoRow(label: lang.isRTL ? 'مستوى المخاطرة' : 'Risk Level', value: _localizedRisk(result.riskLevel, lang)),
          ] else ...[
            const SizedBox(height: 18),
            _NoDetectionBanner(result: result),
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

String _localizedStatus(String status, LanguageProvider lang) {
  switch (status) {
    case 'completed': return lang.t('scan.statusCompleted');
    case 'processing': return lang.t('scan.statusProcessing');
    case 'pending': return lang.t('scan.statusPending');
    case 'failed': return lang.t('scan.statusFailed');
    default: return status;
  }
}

String _localizedRisk(String risk, LanguageProvider lang) {
  switch (risk) {
    case 'high': return lang.t('scan.riskHigh');
    case 'medium': return lang.t('scan.riskMedium');
    case 'low': return lang.t('scan.riskLow');
    default: return risk;
  }
}

class _TopPredictionsCard extends StatelessWidget {
  const _TopPredictionsCard({required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
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
          Text(lang.isRTL ? 'أفضل التنبؤات' : 'Top Predictions',
              style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 18, fontWeight: FontWeight.w700)),
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
                      Text('${lang.localizeNum(percent)}%',
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
