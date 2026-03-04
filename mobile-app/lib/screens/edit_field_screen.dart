import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

/// Edit field screen — pre-filled form (reuses AddField layout)
class EditFieldScreen extends StatelessWidget {
  final String fieldId;
  const EditFieldScreen({super.key, required this.fieldId});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Padding(padding: const EdgeInsets.all(8),
                      child: Transform.flip(flipX: lang.isRTL, child: const Icon(Icons.arrow_back, size: 28, color: AppColors.textSecondary))),
                ),
                const SizedBox(width: 16),
                Text(lang.isRTL ? 'تعديل الحقل' : 'Edit Field',
                    style: const TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w600)),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _prefilledField(lang.t('addField.name'), lang.isRTL ? 'الحقل أ' : 'Field A'),
                  const SizedBox(height: 24),
                  _prefilledField(lang.t('addField.location'), lang.isRTL ? 'القسم الشمالي' : 'North Section'),
                  const SizedBox(height: 24),
                  _prefilledField(lang.t('addField.area'), '2.5'),
                  const SizedBox(height: 24),
                  _prefilledField(lang.t('addField.cropType'), lang.t('crops.tomatoes')),
                  const SizedBox(height: 24),
                  _prefilledField(lang.t('addField.soilType'), lang.t('soil.loamy')),
                  const SizedBox(height: 24),
                  _prefilledField(lang.t('addField.irrigation'), lang.t('irrigation.drip')),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(lang.t('common.save'), style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF44336),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        side: const BorderSide(color: Color(0xFFF44336), width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(lang.t('common.delete'), style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prefilledField(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.primaryDark, fontSize: 18)),
      const SizedBox(height: 12),
      TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    ]);
  }
}
