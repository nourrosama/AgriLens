import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/plan_gate.dart';

class InsuranceReportScreen extends StatefulWidget {
  const InsuranceReportScreen({super.key});

  @override
  State<InsuranceReportScreen> createState() =>
      _InsuranceReportScreenState();
}

class _InsuranceReportScreenState extends State<InsuranceReportScreen> {
  bool _generating = false;
  bool _generated = false;
  String _selectedDisease = '';
  DateTime _eventDate = DateTime.now();
  final _farmerNameCtrl = TextEditingController();
  final _farmNameCtrl = TextEditingController();
  final _estimatedLossCtrl = TextEditingController();

  @override
  void dispose() {
    _farmerNameCtrl.dispose();
    _farmNameCtrl.dispose();
    _estimatedLossCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    await Future.delayed(const Duration(seconds: 2)); // simulate PDF gen
    if (mounted) setState(() { _generating = false; _generated = true; });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();
    final scanProvider = context.watch<ScanHistoryProvider>();
    final isRTL = lang.isRTL;

    if (user.plan != 'professional') {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _appBar(isRTL, context),
        body: PlanGateBody(requiredPlan: 'professional', isRTL: isRTL),
      );
    }

    final diseases = scanProvider.scans
        .where((s) => s.hasDetection && !s.isHealthy)
        .map((s) => s.diseaseNameEn)
        .toSet()
        .toList();

    if (_selectedDisease.isEmpty && diseases.isNotEmpty) {
      _selectedDisease = diseases.first;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _appBar(isRTL, context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF1565C0)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isRTL
                          ? 'يُنشئ هذا التقرير مستندًا رسميًا مُنسقًا لمطالبات التأمين الزراعي يتضمن بيانات المرض والثقة والخسائر المقدرة.'
                          : 'This generates a formatted document for agricultural insurance claims, including disease data, confidence scores and estimated losses.',
                      style: const TextStyle(
                          color: Color(0xFF0D47A1),
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Form
            _FormCard(
              title: isRTL ? 'بيانات المزارع' : 'Farmer Details',
              children: [
                _FormField(
                  label: isRTL ? 'اسم المزارع' : 'Farmer Name',
                  controller: _farmerNameCtrl,
                  hint: isRTL ? 'الاسم الكامل' : 'Full name',
                ),
                const SizedBox(height: 12),
                _FormField(
                  label: isRTL ? 'اسم المزرعة' : 'Farm Name',
                  controller: _farmNameCtrl,
                  hint: isRTL ? 'اسم المزرعة أو موقعها' : 'Farm name or location',
                ),
              ],
            ),
            const SizedBox(height: 12),

            _FormCard(
              title: isRTL ? 'بيانات حدث المرض' : 'Disease Event Details',
              children: [
                // Disease selector
                Text(isRTL ? 'المرض المُكتشف:' : 'Detected Disease:',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 13)),
                const SizedBox(height: 6),
                diseases.isEmpty
                    ? Text(
                        isRTL
                            ? 'لا توجد أمراض مسجلة بعد'
                            : 'No diseases recorded yet',
                        style: const TextStyle(
                            color: AppColors.textSecondary),
                      )
                    : DropdownButtonFormField<String>(
                        value: _selectedDisease.isEmpty ? null : _selectedDisease,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: diseases
                            .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(d,
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedDisease = v ?? ''),
                      ),
                const SizedBox(height: 12),
                // Event date
                Text(isRTL ? 'تاريخ الحادثة:' : 'Event Date:',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontSize: 13)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _eventDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _eventDate = picked);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFBDBDBD)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          '${_eventDate.year}-${_eventDate.month.toString().padLeft(2, '0')}-${_eventDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FormField(
                  label: isRTL ? 'الخسارة المقدرة (جنيه)' : 'Estimated Loss (EGP)',
                  controller: _estimatedLossCtrl,
                  hint: '0.00',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Generate button
            if (!_generated)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: _generating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.file_download_rounded),
                  label: Text(
                    _generating
                        ? (isRTL ? 'جارٍ الإنشاء…' : 'Generating…')
                        : (isRTL ? 'إنشاء تقرير التأمين' : 'Generate Insurance Report'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

            if (_generated) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4CAF50)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isRTL
                                ? 'تم إنشاء التقرير بنجاح!'
                                : 'Insurance report generated!',
                            style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.share_rounded,
                                size: 18),
                            label: Text(isRTL ? 'مشاركة' : 'Share'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.download_rounded,
                                size: 18),
                            label: Text(isRTL ? 'تحميل PDF' : 'Download PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(bool isRTL, BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: const Icon(Icons.arrow_back,
            color: AppColors.textSecondary),
      ),
      title: Text(
        isRTL ? 'توثيق التأمين' : 'Insurance Documentation',
        style: const TextStyle(
            color: AppColors.primaryDark, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const Divider(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
  });
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}
