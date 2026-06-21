import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';

class ScanHistoryScreen extends StatelessWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final scanProvider = context.watch<ScanHistoryProvider>();
    final scans = scanProvider.scans;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF424242)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          lang.t('scanHistory.title'),
          style: const TextStyle(
            color: Color(0xFF2E7D32),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE0E0E0)),
        ),
      ),
      body: scanProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : scans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.eco_outlined, size: 64, color: Color(0xFFBDBDBD)),
                      const SizedBox(height: 16),
                      Text(
                        lang.t('scanHistory.empty'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF757575), fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/crop-select'),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: Text(lang.t('home.quickScan')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: scanProvider.loadScans,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (scanProvider.historyLimited)
                        _HistoryLimitBanner(reason: scanProvider.historyLimitReason),
                      ...scans.asMap().entries.map((entry) {
                        return Padding(
                          padding: EdgeInsets.only(
                            top: entry.key == 0 && !scanProvider.historyLimited ? 0 : 12,
                          ),
                          child: _ScanTile(scan: entry.value, lang: lang),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _HistoryLimitBanner extends StatelessWidget {
  const _HistoryLimitBanner({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    const rankMap = {'free': 0, 'premium': 1, 'professional': 2};
    final currentRank = rankMap[user.plan] ?? 0;
    final highestRank = rankMap.values.reduce((a, b) => a > b ? a : b);
    final canUpgrade = currentRank < highestRank;

    // Label for the upgrade button depends on current plan
    String upgradeLabel;
    if (user.plan == 'premium') {
      upgradeLabel = 'Upgrade to Professional';
    } else {
      upgradeLabel = 'Upgrade to Premium';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB300), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFFFFB300), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Limited History',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6D4C00),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason.isNotEmpty
                      ? reason
                      : 'Free plan: showing your last 3 scans this week.',
                  style: const TextStyle(color: Color(0xFF6D4C00), fontSize: 13),
                ),
                if (canUpgrade) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push('/subscription-plans'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB300),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text(
                        upgradeLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanTile extends StatelessWidget {
  const _ScanTile({required this.scan, required this.lang});

  final ScanResult scan;
  final LanguageProvider lang;

  @override
  Widget build(BuildContext context) {
    final isProcessing = scan.status == 'processing' || scan.status == 'pending';
    final isFailed = scan.status == 'failed' || scan.status == 'invalid_image';
    final diseaseLabel = isProcessing
        ? lang.t('scanHistory.processing')
        : isFailed
            ? lang.t('scan.noResults')
            : scan.isHealthy
                ? lang.t('scanHistory.healthy')
                : (lang.isRTL ? scan.diseaseNameAr : scan.diseaseNameEn);

    final statusColor = isProcessing
        ? const Color(0xFF9E9E9E)
        : isFailed
            ? const Color(0xFF9E9E9E)
            : scan.isHealthy
                ? const Color(0xFF4CAF50)
                : _severityColor(scan.severity);

    final date = _formatDate(scan.scannedAt, lang.isRTL);

    return GestureDetector(
      onTap: () => context.push('/scan-result', extra: scan),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon / thumbnail
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  scan.isVideo ? Icons.videocam_rounded : Icons.eco_rounded,
                  color: statusColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            diseaseLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF212121),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Status chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusLabel(scan, lang, isProcessing, isFailed),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (scan.cropType.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              scan.cropType,
                              style: const TextStyle(color: Color(0xFF757575), fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text('  ·  ', style: TextStyle(color: Color(0xFFBDBDBD))),
                        ],
                        Text(
                          date,
                          style: const TextStyle(color: Color(0xFF757575), fontSize: 13),
                        ),
                        if (scan.hasDetection && !scan.isHealthy) ...[
                          const Text('  ·  ', style: TextStyle(color: Color(0xFFBDBDBD))),
                          Flexible(
                            child: Text(
                              '${(scan.confidence * 100).round()}% ${lang.t('scan.confidence')}',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(
    ScanResult scan,
    LanguageProvider lang,
    bool isProcessing,
    bool isFailed,
  ) {
    if (isProcessing) return lang.isRTL ? 'معالجة' : 'Processing';
    if (isFailed) return lang.isRTL ? 'فشل' : 'Failed';
    if (scan.isHealthy) return lang.t('scanHistory.healthy');
    switch (scan.severity) {
      case 'high':
        return lang.isRTL ? 'خطر مرتفع' : 'High risk';
      case 'medium':
        return lang.isRTL ? 'خطر متوسط' : 'Medium risk';
      default:
        return lang.isRTL ? 'خطر منخفض' : 'Low risk';
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'high':
      case 'critical':
        return const Color(0xFFF44336);
      case 'medium':
        return const Color(0xFFFFC107);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  String _formatDate(DateTime dt, bool isRTL) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      if (diff.inSeconds < 60) return isRTL ? 'الآن' : 'Just now';
      if (diff.inMinutes < 60) {
        return isRTL ? 'منذ ${diff.inMinutes} دقيقة' : '${diff.inMinutes}m ago';
      }
      return isRTL ? 'منذ ${diff.inHours} ساعة' : '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) return isRTL ? 'أمس' : 'Yesterday';
    if (diff.inDays < 7) return isRTL ? 'منذ ${diff.inDays} أيام' : '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
