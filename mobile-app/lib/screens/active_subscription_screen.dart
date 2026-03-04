import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

class ActiveSubscriptionScreen extends StatelessWidget {
  const ActiveSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(children: [
              GestureDetector(onTap: () => context.pop(),
                child: Padding(padding: const EdgeInsets.all(8),
                  child: Transform.flip(flipX: lang.isRTL,
                    child: const Icon(Icons.arrow_back, size: 28, color: AppColors.textSecondary)))),
              const SizedBox(width: 16),
              Text(lang.t('subscription.manage'),
                  style: const TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w600)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                // Active plan
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(lang.t('subscription.premium'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text(lang.isRTL ? 'نشط' : 'Active', style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Text('\$9.99${lang.t('subscription.month')}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 24),
                // Details
                _detailCard(lang, [
                  [lang.t('subscription.renewDate'), lang.isRTL ? '15 مارس 2026' : 'March 15, 2026'],
                  [lang.t('subscription.usage'), ''],
                ]),
                const SizedBox(height: 16),
                // Usage bars
                _usageCard(lang),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF44336),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      side: const BorderSide(color: Color(0xFFF44336), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(lang.t('subscription.cancelPlan'), style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _detailCard(LanguageProvider lang, List<List<String>> items) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        children: items.where((i) => i[1].isNotEmpty).map((i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(i[0], style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            Text(i[1], style: const TextStyle(color: AppColors.primaryDark, fontSize: 16)),
          ]),
        )).toList(),
      ),
    );
  }

  Widget _usageCard(LanguageProvider lang) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(lang.t('subscription.usage'),
            style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        _usageBar(lang.t('nav.scan'), '156', lang.isRTL ? 'غير محدود' : 'Unlimited', 0.6),
        const SizedBox(height: 16),
        _usageBar(lang.t('nav.fields'), '3', '10', 0.3),
        const SizedBox(height: 16),
        _usageBar(lang.t('nav.reports'), '8', lang.isRTL ? 'غير محدود' : 'Unlimited', 0.4),
      ]),
    );
  }

  Widget _usageBar(String label, String used, String total, double progress) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        Text('$used / $total', style: const TextStyle(color: AppColors.primaryDark, fontSize: 14)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: AppColors.background, valueColor: const AlwaysStoppedAnimation(AppColors.primary))),
    ]);
  }
}
