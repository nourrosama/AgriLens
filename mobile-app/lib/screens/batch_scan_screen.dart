import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/plan_gate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

enum _BatchItemStatus { pending, scanning, done, failed }

class _BatchItem {
  _BatchItemStatus status;
  final String name;
  ScanResult? result;
  String? error;

  _BatchItem({required this.name, this.status = _BatchItemStatus.pending});
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class BatchScanScreen extends StatefulWidget {
  const BatchScanScreen({super.key});

  @override
  State<BatchScanScreen> createState() => _BatchScanScreenState();
}

class _BatchScanScreenState extends State<BatchScanScreen> {
  final List<_BatchItem> _items = [];
  String _cropType = 'tomato';
  bool _running = false;
  bool _done = false;

  final List<String> _cropOptions = [
    'tomato', 'potato', 'pepper', 'corn', 'wheat',
    'rice', 'apple', 'grape', 'strawberry', 'other',
  ];

  Future<void> _pickImages() async {
    // In a real app, use image_picker with allowMultiple.
    // Here we simulate adding 3 mock entries to show the UX.
    if (_running) return;
    setState(() {
      for (var i = _items.length + 1; i <= _items.length + 3; i++) {
        _items.add(_BatchItem(name: 'scan_$i.jpg'));
      }
    });
  }

  void _removeItem(int index) {
    if (_running) return;
    setState(() => _items.removeAt(index));
  }

  Future<void> _runBatch() async {
    if (_items.isEmpty || _running) return;
    setState(() {
      _running = true;
      _done = false;
    });

    final scanProvider = context.read<ScanHistoryProvider>();

    for (final item in _items) {
      if (!mounted) break;
      setState(() => item.status = _BatchItemStatus.scanning);
      await Future.delayed(const Duration(milliseconds: 900)); // simulate API
      setState(() {
        // In real use: call scanProvider.submitScan() per image
        item.status = _BatchItemStatus.done;
      });
    }

    if (mounted) {
      setState(() {
        _running = false;
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();
    final isRTL = lang.isRTL;
    final canAccess =
        user.plan == 'premium' || user.plan == 'professional';

    if (!canAccess) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          ),
          title: Text(
            isRTL ? 'مسح متعدد' : 'Batch Scan',
            style: const TextStyle(
                color: AppColors.primaryDark, fontWeight: FontWeight.bold),
          ),
        ),
        body: PlanGateBody(requiredPlan: 'premium', isRTL: isRTL),
      );
    }

    final doneCount =
        _items.where((i) => i.status == _BatchItemStatus.done).length;
    final failedCount =
        _items.where((i) => i.status == _BatchItemStatus.failed).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
        ),
        title: Text(
          isRTL ? 'مسح متعدد' : 'Batch Scan',
          style: const TextStyle(
              color: AppColors.primaryDark, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_running && _items.isNotEmpty && !_done)
            TextButton(
              onPressed: () => setState(() => _items.clear()),
              child: Text(isRTL ? 'مسح الكل' : 'Clear All',
                  style: const TextStyle(color: Color(0xFFF44336))),
            ),
        ],
      ),
      body: Column(
        children: [
          // Crop type selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Text(
                  isRTL ? 'نوع المحصول:' : 'Crop type:',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _cropType,
                      isExpanded: true,
                      onChanged: _running
                          ? null
                          : (v) => setState(() => _cropType = v!),
                      items: _cropOptions
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c[0].toUpperCase() + c.substring(1),
                                style:
                                    const TextStyle(fontSize: 14),
                              )))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Image list
          Expanded(
            child: _items.isEmpty
                ? _EmptyPicker(isRTL: isRTL, onTap: _pickImages)
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) => _BatchTile(
                      item: _items[i],
                      index: i,
                      onRemove: () => _removeItem(i),
                    ),
                  ),
          ),

          // Bottom controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_done) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isRTL
                                  ? 'اكتمل: $doneCount ناجح، $failedCount فشل'
                                  : 'Complete: $doneCount succeeded, $failedCount failed',
                              style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _running ? null : _pickImages,
                          icon: const Icon(Icons.add_photo_alternate_rounded),
                          label: Text(isRTL ? 'إضافة صور' : 'Add Images'),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _items.isEmpty || _running ? null : _runBatch,
                          icon: _running
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.play_arrow_rounded),
                          label: Text(
                              _running
                                  ? (isRTL ? 'جارٍ المسح…' : 'Scanning…')
                                  : (isRTL ? 'بدء المسح' : 'Start Scan'),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),
                    ],
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

class _EmptyPicker extends StatelessWidget {
  const _EmptyPicker({required this.isRTL, required this.onTap});
  final bool isRTL;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                style: BorderStyle.solid,
                width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_photo_alternate_rounded,
                  size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                isRTL
                    ? 'اضغط لاختيار صور متعددة'
                    : 'Tap to select multiple images',
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isRTL
                    ? 'يمكنك تحميل حتى ٢٠ صورة في وقت واحد'
                    : 'Upload up to 20 images at once',
                style: const TextStyle(
                    color: Color(0xFF9E9E9E), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  const _BatchTile(
      {required this.item, required this.index, required this.onRemove});
  final _BatchItem item;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final statusColor = item.status == _BatchItemStatus.done
        ? const Color(0xFF4CAF50)
        : item.status == _BatchItemStatus.failed
            ? const Color(0xFFF44336)
            : item.status == _BatchItemStatus.scanning
                ? const Color(0xFF1976D2)
                : const Color(0xFF9E9E9E);

    final statusIcon = item.status == _BatchItemStatus.done
        ? Icons.check_circle_rounded
        : item.status == _BatchItemStatus.failed
            ? Icons.error_rounded
            : item.status == _BatchItemStatus.scanning
                ? Icons.sync_rounded
                : Icons.image_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                      color: Color(0xFF424242),
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                if (item.status == _BatchItemStatus.scanning)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(
                      color: Color(0xFF1976D2),
                      backgroundColor: Color(0xFFE3F2FD),
                    ),
                  )
                else if (item.result != null)
                  Text(
                    item.result!.diseaseNameEn,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (item.status == _BatchItemStatus.pending)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF9E9E9E)),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
