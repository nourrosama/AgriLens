import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/plan_gate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Simple in-memory annotation store (keyed by scan ID)
// In production, persist via SharedPreferences or a backend endpoint.
// ─────────────────────────────────────────────────────────────────────────────

class ScanAnnotationStore {
  static final ScanAnnotationStore _instance =
      ScanAnnotationStore._internal();
  factory ScanAnnotationStore() => _instance;
  ScanAnnotationStore._internal();

  final Map<String, List<_Annotation>> _notes = {};

  List<_Annotation> get(String scanId) => _notes[scanId] ?? [];

  void add(String scanId, _Annotation note) {
    _notes.putIfAbsent(scanId, () => []).insert(0, note);
  }

  void remove(String scanId, String noteId) {
    _notes[scanId]?.removeWhere((n) => n.id == noteId);
  }
}

class _Annotation {
  final String id;
  final String text;
  final DateTime createdAt;

  _Annotation({required this.id, required this.text, required this.createdAt});
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ScanAnnotationScreen extends StatefulWidget {
  const ScanAnnotationScreen({super.key, required this.scanId});
  final String scanId;

  @override
  State<ScanAnnotationScreen> createState() => _ScanAnnotationScreenState();
}

class _ScanAnnotationScreenState extends State<ScanAnnotationScreen> {
  final _store = ScanAnnotationStore();
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addNote() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 300));
    _store.add(
      widget.scanId,
      _Annotation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        createdAt: DateTime.now(),
      ),
    );
    _controller.clear();
    if (mounted) setState(() => _saving = false);
  }

  void _deleteNote(String noteId) {
    setState(() => _store.remove(widget.scanId, noteId));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();
    final scanProvider = context.watch<ScanHistoryProvider>();
    final isRTL = lang.isRTL;
    final canAccess =
        user.plan == 'premium' || user.plan == 'professional';

    // Guard: no scans loaded yet
    if (scanProvider.scans.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back,
                color: AppColors.textSecondary),
          ),
          title: Text(
            isRTL ? 'ملاحظات الفحص' : 'Scan Notes',
            style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history_rounded,
                    size: 64, color: Color(0xFFBDBDBD)),
                const SizedBox(height: 16),
                Text(
                  isRTL
                      ? 'لا توجد فحوصات بعد'
                      : 'No scans yet',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF616161)),
                ),
                const SizedBox(height: 8),
                Text(
                  isRTL
                      ? 'افحص نباتًا أولاً ثم أضف ملاحظات من سجل الفحوصات'
                      : 'Scan a plant first, then add notes from the scan history',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF9E9E9E), fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => context.push('/crop-select'),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: Text(isRTL ? 'ابدأ الفحص' : 'Start Scan'),
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
        ),
      );
    }

    final scan = scanProvider.scans.firstWhere(
      (s) => s.id == widget.scanId,
      orElse: () => scanProvider.scans.first,
    );

    if (!canAccess) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back,
                color: AppColors.textSecondary),
          ),
          title: Text(
            isRTL ? 'ملاحظات الفحص' : 'Scan Notes',
            style: const TextStyle(
                color: AppColors.primaryDark, fontWeight: FontWeight.bold),
          ),
        ),
        body: PlanGateBody(requiredPlan: 'premium', isRTL: isRTL),
      );
    }

    final notes = _store.get(widget.scanId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back,
              color: AppColors.textSecondary),
        ),
        title: Text(
          isRTL ? 'ملاحظات الفحص' : 'Scan Notes',
          style: const TextStyle(
              color: AppColors.primaryDark, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Scan summary header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.pest_control_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scan.diseaseNameEn.isEmpty
                            ? (isRTL ? 'فحص بدون عنوان' : 'Untitled scan')
                            : scan.diseaseNameEn,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatDate(scan.scannedAt, isRTL),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _sevColor(scan.severity)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    scan.severity.toUpperCase(),
                    style: TextStyle(
                        color: _sevColor(scan.severity),
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Notes list
          Expanded(
            child: notes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.notes_rounded,
                              size: 56, color: Color(0xFFBDBDBD)),
                          const SizedBox(height: 12),
                          Text(
                            isRTL
                                ? 'لا توجد ملاحظات بعد'
                                : 'No notes yet',
                            style: const TextStyle(
                                color: Color(0xFF616161),
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isRTL
                                ? 'أضف ملاحظاتك حول هذا الفحص أدناه'
                                : 'Add your observations below',
                            style: const TextStyle(
                                color: Color(0xFF9E9E9E), fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notes.length,
                    itemBuilder: (ctx, i) => _NoteCard(
                      note: notes[i],
                      isRTL: isRTL,
                      onDelete: () => _deleteNote(notes[i].id),
                    ),
                  ),
          ),

          // Note input
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: isRTL
                          ? 'أضف ملاحظة أو مشاهدة…'
                          : 'Add a note or observation…',
                      hintStyle:
                          const TextStyle(color: Color(0xFFBDBDBD)),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _saving ? null : _addNote,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _saving
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _sevColor(String severity) {
    switch (severity) {
      case 'high':
        return const Color(0xFFF44336);
      case 'medium':
        return const Color(0xFFFFC107);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  String _formatDate(DateTime dt, bool isRTL) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ─── Note card ─────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  const _NoteCard(
      {required this.note, required this.isRTL, required this.onDelete});
  final _Annotation note;
  final bool isRTL;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dt = note.createdAt;
    final dateStr =
        '${months[dt.month - 1]} ${dt.day}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes_rounded,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                dateStr,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline,
                    size: 16, color: Color(0xFFBDBDBD)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note.text,
            style: const TextStyle(
                color: Color(0xFF424242), fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
