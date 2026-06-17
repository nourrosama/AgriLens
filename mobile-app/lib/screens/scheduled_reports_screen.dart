import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/plan_gate.dart';

class _ScheduledReport {
  final String id;
  String frequency; // 'weekly' | 'monthly'
  String delivery; // 'notification' | 'sms'
  String contact; // phone or 'app'
  bool enabled;

  _ScheduledReport({
    required this.id,
    required this.frequency,
    required this.delivery,
    required this.contact,
    this.enabled = true,
  });
}

class ScheduledReportsScreen extends StatefulWidget {
  const ScheduledReportsScreen({super.key});

  @override
  State<ScheduledReportsScreen> createState() =>
      _ScheduledReportsScreenState();
}

class _ScheduledReportsScreenState extends State<ScheduledReportsScreen> {
  final List<_ScheduledReport> _schedules = [
    _ScheduledReport(
      id: '1',
      frequency: 'weekly',
      delivery: 'notification',
      contact: 'app',
    ),
  ];

  void _addSchedule(BuildContext context, bool isRTL) {
    String freq = 'weekly';
    String delivery = 'notification';
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isRTL ? 'جدولة تقرير جديد' : 'Schedule New Report',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark),
              ),
              const SizedBox(height: 16),
              // Frequency
              Text(isRTL ? 'التكرار:' : 'Frequency:',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ToggleChip(
                    label: isRTL ? 'أسبوعي' : 'Weekly',
                    selected: freq == 'weekly',
                    onTap: () => setModal(() => freq = 'weekly'),
                  ),
                  const SizedBox(width: 10),
                  _ToggleChip(
                    label: isRTL ? 'شهري' : 'Monthly',
                    selected: freq == 'monthly',
                    onTap: () => setModal(() => freq = 'monthly'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Delivery
              Text(isRTL ? 'طريقة الإرسال:' : 'Delivery:',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ToggleChip(
                    label: isRTL ? '📱 إشعار' : '📱 Notification',
                    selected: delivery == 'notification',
                    onTap: () => setModal(() => delivery = 'notification'),
                  ),
                  const SizedBox(width: 10),
                  _ToggleChip(
                    label: isRTL ? '📲 SMS' : '📲 SMS',
                    selected: delivery == 'sms',
                    onTap: () => setModal(() => delivery = 'sms'),
                  ),
                ],
              ),
              if (delivery == 'sms') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText:
                        isRTL ? 'رقم الهاتف' : 'Phone Number',
                    hintText: '+20 1XX XXX XXXX',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _schedules.add(_ScheduledReport(
                        id: DateTime.now()
                            .millisecondsSinceEpoch
                            .toString(),
                        frequency: freq,
                        delivery: delivery,
                        contact: delivery == 'sms'
                            ? phoneCtrl.text.trim()
                            : 'app',
                      ));
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isRTL
                            ? 'تم جدولة التقرير!'
                            : 'Report scheduled!'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child:
                      Text(isRTL ? 'حفظ الجدول' : 'Save Schedule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();
    final isRTL = lang.isRTL;

    if (user.plan != 'professional') {
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
            isRTL ? 'التقارير المجدولة' : 'Scheduled Reports',
            style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold),
          ),
        ),
        body: PlanGateBody(requiredPlan: 'professional', isRTL: isRTL),
      );
    }

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
          isRTL ? 'التقارير المجدولة' : 'Scheduled Reports',
          style: const TextStyle(
              color: AppColors.primaryDark, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            onPressed: () => _addSchedule(context, isRTL),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSchedule(context, isRTL),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(isRTL ? 'جدولة جديدة' : 'New Schedule',
            style: const TextStyle(color: Colors.white)),
      ),
      body: _schedules.isEmpty
          ? _EmptySchedules(isRTL: isRTL)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _schedules.length,
              itemBuilder: (ctx, i) {
                final s = _schedules[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          s.frequency == 'weekly'
                              ? Icons.date_range_rounded
                              : Icons.calendar_month_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.frequency == 'weekly'
                                  ? (isRTL ? 'تقرير أسبوعي' : 'Weekly Report')
                                  : (isRTL ? 'تقرير شهري' : 'Monthly Report'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF212121)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              s.delivery == 'sms'
                                  ? 'SMS → ${s.contact}'
                                  : (isRTL
                                      ? 'إشعار في التطبيق'
                                      : 'App notification'),
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: s.enabled,
                        activeColor: AppColors.primary,
                        onChanged: (v) =>
                            setState(() => s.enabled = v),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _schedules.removeAt(i)),
                        child: const Icon(Icons.delete_outline,
                            color: Color(0xFFBDBDBD), size: 20),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip(
      {required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? AppColors.primary
                  : const Color(0xFFE0E0E0)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color:
                  selected ? Colors.white : const Color(0xFF616161),
              fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _EmptySchedules extends StatelessWidget {
  const _EmptySchedules({required this.isRTL});
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded,
                size: 72, color: Color(0xFFBDBDBD)),
            const SizedBox(height: 16),
            Text(
              isRTL ? 'لا توجد تقارير مجدولة' : 'No scheduled reports',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF616161)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isRTL
                  ? 'أضف جدولة لاستقبال تقارير الحقل تلقائيًا'
                  : 'Add a schedule to receive field reports automatically',
              style: const TextStyle(
                  color: Color(0xFF9E9E9E), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
