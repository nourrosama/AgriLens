import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

class DiseaseMapScreen extends StatelessWidget {
  const DiseaseMapScreen({super.key});

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
                    child: Transform.flip(flipX: lang.isRTL, child: const Icon(Icons.arrow_back, size: 28, color: AppColors.textSecondary)))),
              const SizedBox(width: 16),
              Text(lang.t('diseaseMap.title'), style: const TextStyle(color: AppColors.primaryDark, fontSize: 20, fontWeight: FontWeight.w600)),
            ]),
          ),
          Expanded(
            child: Stack(children: [
              // Map mockup
              Container(
                color: const Color(0xFFE8F5E9),
                child: GridView.count(
                  crossAxisCount: 8, padding: const EdgeInsets.all(16),
                  mainAxisSpacing: 4, crossAxisSpacing: 4,
                  children: List.generate(64, (i) {
                    final rng = Random(i * 7);
                    final colors = [const Color(0xFFA5D6A7), const Color(0xFF66BB6A), const Color(0xFFFFF176), const Color(0xFFFFB74D), const Color(0xFFEF5350)];
                    return Container(decoration: BoxDecoration(color: colors[rng.nextInt(rng.nextDouble() > 0.7 ? 5 : 3)], borderRadius: BorderRadius.circular(4)));
                  }),
                ),
              ),
              // Legend
              Positioned(
                bottom: 24, left: 24, right: 24,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lang.t('diseaseMap.legend'), style: const TextStyle(color: AppColors.primaryDark, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _legendItem(const Color(0xFF66BB6A), lang.t('diseaseMap.noDisease')),
                      _legendItem(const Color(0xFFFFF176), lang.t('diseaseMap.lowRisk')),
                      _legendItem(const Color(0xFFFFB74D), lang.t('diseaseMap.moderateRisk')),
                      _legendItem(const Color(0xFFEF5350), lang.t('diseaseMap.highRisk')),
                    ]),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    ]);
  }
}
