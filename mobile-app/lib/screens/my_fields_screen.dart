import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/widgets/bottom_nav.dart';
import 'package:agrilens/widgets/chatbot_button.dart';

class MyFieldsScreen extends StatelessWidget {
  const MyFieldsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final fields = [
      _Field(1, lang.isRTL ? 'الحقل أ' : 'Field A',
          lang.isRTL ? 'القسم الشمالي' : 'North Section', '2.5', 'healthy', 92),
      _Field(2, lang.isRTL ? 'الحقل ب' : 'Field B',
          lang.isRTL ? 'القسم الشرقي' : 'East Section', '3.2', 'warning', 68),
      _Field(3, lang.isRTL ? 'الحقل ج' : 'Field C',
          lang.isRTL ? 'القسم الجنوبي' : 'South Section', '1.8', 'healthy', 88),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/home'),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Transform.flip(flipX: lang.isRTL,
                              child: const Icon(Icons.arrow_back, size: 28, color: AppColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Text(lang.t('fields.title'),
                          style: const TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w600))),
                      GestureDetector(
                        onTap: () => context.push('/disease-map'),
                        child: Text(lang.t('fields.viewMap'),
                            style: const TextStyle(color: AppColors.primary, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Add field button
                        GestureDetector(
                          onTap: () => context.push('/add-field'),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.primary, width: 2, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add, color: AppColors.primary, size: 28),
                                const SizedBox(width: 12),
                                Text(lang.t('fields.addNew'),
                                    style: const TextStyle(color: AppColors.primary, fontSize: 18)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Field cards
                        ...fields.map((f) => _fieldCard(context, lang, f)),
                        const SizedBox(height: 16),
                        // Quick stats
                        _quickStats(lang),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const ChatbotButton(),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(active: 'fields'),
    );
  }

  Widget _fieldCard(BuildContext context, LanguageProvider lang, _Field f) {
    return GestureDetector(
      onTap: () => context.push('/field-overview/${f.id}'),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.name, style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(f.location, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ]),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: f.status == 'healthy' ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    f.status == 'healthy' ? lang.t('fields.healthy') : lang.t('fields.warning'),
                    style: TextStyle(color: f.status == 'healthy' ? AppColors.primary : const Color(0xFFFFC107), fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lang.t('fields.area'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 4),
                Text('${f.area} ${lang.t('units.feddan')}', style: const TextStyle(color: AppColors.primaryDark, fontSize: 18)),
              ]),
              const SizedBox(width: 48),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lang.t('fields.healthScore'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 4),
                Text('${f.health}${lang.t('units.percent')}', style: const TextStyle(color: AppColors.primaryDark, fontSize: 18)),
              ]),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: f.health / 100,
                minHeight: 8,
                backgroundColor: AppColors.background,
                valueColor: AlwaysStoppedAnimation(f.health >= 80 ? AppColors.primary : const Color(0xFFFFC107)),
              ),
            ),
            if (f.status == 'warning') ...[
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFFFC107)),
                const SizedBox(width: 8),
                Text('2 ${lang.t('fields.riskDetected')}',
                    style: const TextStyle(color: Color(0xFFFFC107), fontSize: 14)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quickStats(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.t('fields.overview'), style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _statBox(lang.t('fields.totalArea'), '7.5 ${lang.t('units.feddan')}')),
            const SizedBox(width: 16),
            Expanded(child: _statBox(lang.t('fields.avgHealth'), '83${lang.t('units.percent')}')),
          ]),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.primaryDark, fontSize: 18)),
      ]),
    );
  }
}

class _Field {
  final int id;
  final String name, location, area, status;
  final int health;
  _Field(this.id, this.name, this.location, this.area, this.status, this.health);
}
