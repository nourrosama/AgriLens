import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/disease_local_db.dart';
import 'package:agrilens/core/favourites_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final favourites = context.watch<FavouritesProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Transform.flip(
                        flipX: lang.isRTL,
                        child: const Icon(Icons.arrow_back,
                            size: 28, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    lang.isRTL ? 'المفضلة' : 'Favourites',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFFC107), size: 24),
                ],
              ),
            ),

            Expanded(
              child: favourites.ids.isEmpty
                  ? _emptyState(lang)
                  : FutureBuilder<List<LocalDisease>>(
                      future: _loadFavourites(favourites.ids),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          );
                        }
                        final diseases = snapshot.data!;
                        return ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: diseases.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) =>
                              _DiseaseCard(disease: diseases[i]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<LocalDisease>> _loadFavourites(List<String> ids) async {
    final all = await DiseaseLocalDb.instance.all();
    // Preserve bookmark order; skip IDs not found in local DB.
    final map = {for (final d in all) d.id: d};
    return ids.map((id) => map[id]).whereType<LocalDisease>().toList();
  }

  Widget _emptyState(LanguageProvider lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_border_rounded,
                size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              lang.isRTL
                  ? 'لا توجد مفضلات بعد'
                  : 'No favourites yet',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lang.isRTL
                  ? 'اضغط على النجمة في تفاصيل المرض لإضافته'
                  : 'Tap the star on any disease details screen to bookmark it',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiseaseCard extends StatelessWidget {
  const _DiseaseCard({required this.disease});
  final LocalDisease disease;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final favourites = context.read<FavouritesProvider>();
    final name = lang.isRTL ? disease.nameAr : disease.nameEn;
    final crop = lang.isRTL ? disease.cropAr : disease.cropEn;
    final symptoms = lang.isRTL ? disease.symptomsAr : disease.symptomsEn;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
                    Text(name,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        )),
                    if (disease.scientificName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(disease.scientificName,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => favourites.toggle(disease.id),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.star_rounded,
                      color: Color(0xFFFFC107), size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip(crop, AppColors.primary),
              const SizedBox(width: 8),
              _chip(_severityLabel(disease.severity, lang.isRTL),
                  _severityColor(disease.severity)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            symptoms,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  String _severityLabel(String s, bool isRTL) {
    switch (s) {
      case 'high':
        return isRTL ? 'خطورة عالية' : 'High';
      case 'medium':
        return isRTL ? 'خطورة متوسطة' : 'Medium';
      case 'none':
        return isRTL ? 'سليم' : 'Healthy';
      default:
        return isRTL ? 'خطورة منخفضة' : 'Low';
    }
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'high':
        return const Color(0xFFF44336);
      case 'medium':
        return const Color(0xFFFFC107);
      case 'none':
        return AppColors.primary;
      default:
        return const Color(0xFF4CAF50);
    }
  }
}
