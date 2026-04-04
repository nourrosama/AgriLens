import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

/// Disease details screen — full breakdown with symptoms, causes, prevention
class DiseaseDetailsScreen extends StatelessWidget {
  const DiseaseDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(context, lang),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _diseaseHeader(lang),
                    const SizedBox(height: 24),
                    _description(lang),
                    const SizedBox(height: 24),
                    _symptoms(lang),
                    const SizedBox(height: 24),
                    _causes(lang),
                    const SizedBox(height: 24),
                    _prevention(lang),
                    const SizedBox(height: 24),
                    _visualExamples(lang),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, LanguageProvider lang) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Transform.flip(
                flipX: lang.isRTL,
                child: const Icon(
                  Icons.arrow_back,
                  size: 28,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            lang.t('disease.overview'),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _diseaseHeader(LanguageProvider lang) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.isRTL ? 'اللفحة المتأخرة' : 'Late Blight',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Phytophthora infestans',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.warning_rounded,
                color: Color(0xFFFFC107),
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.isRTL
                      ? 'مرض عالي الخطورة يتطلب عناية فورية'
                      : 'High-risk disease requiring immediate attention',
                  style: const TextStyle(
                    color: Color(0xFFFFC107),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _description(LanguageProvider lang) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('disease.overview'),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            lang.isRTL
                ? 'اللفحة المتأخرة مرض مدمر يصيب الطماطم والبطاطس. يمكن أن يدمر المحاصيل بالكامل بسرعة إذا ترك دون علاج. ينمو المرض في ظروف باردة ورطبة وينتشر بسرعة عبر رذاذ الماء والرياح.'
                : 'Late blight is a devastating disease that affects tomatoes and potatoes. It can rapidly destroy entire crops if left untreated. The disease thrives in cool, wet conditions and can spread quickly through water splash and wind.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _symptoms(LanguageProvider lang) {
    final items = lang.isRTL
        ? [
            'بقع بنية داكنة إلى سوداء على الأوراق',
            'نمو أبيض ضبابي على الجهة السفلية للأوراق',
            'السيقان تظهر خطوط داكنة',
            'الثمار تظهر بقع بنية دهنية المظهر',
          ]
        : [
            'Dark brown to black lesions on leaves',
            'White fuzzy growth on leaf undersides',
            'Stems develop dark streaks',
            'Fruit shows brown, greasy-looking spots',
          ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                lang.t('disease.symptoms'),
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _causes(LanguageProvider lang) {
    final items = lang.isRTL
        ? [
            ['بيئية', 'درجات حرارة باردة (15-20°س) مع رطوبة عالية'],
            ['الرطوبة', 'فترات طويلة من بلل الأوراق بسبب المطر أو الندى'],
            ['الانتشار', 'جراثيم محمولة بالرياح ورذاذ الماء'],
          ]
        : [
            ['Environmental', 'Cool temperatures (15-20°C) with high humidity'],
            ['Moisture', 'Extended periods of leaf wetness from rain or dew'],
            ['Spread', 'Wind-borne spores and water splash'],
          ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.isRTL ? 'الأسباب' : 'Causes',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (i) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i[0],
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    i[1],
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _prevention(LanguageProvider lang) {
    final steps = lang.isRTL
        ? [
            ['زراعة أصناف مقاومة', 'اختر أصناف مقاومة للفحة عند توفرها'],
            ['تباعد مناسب', 'تأكد من دوران هواء جيد بين النباتات'],
            ['استخدام مبيد فطري', 'استخدم مبيدات فطرية نحاسية أو عضوية كوقاية'],
            ['إزالة المواد المصابة', 'أتلف النباتات المريضة لمنع الانتشار'],
          ]
        : [
            [
              'Plant Resistant Varieties',
              'Choose blight-resistant cultivars when available',
            ],
            ['Proper Spacing', 'Ensure good air circulation between plants'],
            [
              'Fungicide Application',
              'Apply copper-based or organic fungicides preventatively',
            ],
            [
              'Remove Infected Material',
              'Destroy diseased plants to prevent spread',
            ],
          ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '${lang.t('disease.prevention')} & ${lang.t('disease.treatment')}',
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map(
            (e) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.value[0],
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.value[1],
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visualExamples(LanguageProvider lang) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.isRTL ? 'أمثلة بصرية' : 'Visual Examples',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: List.generate(
              4,
              (i) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.primaryDark.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    lang.isRTL ? 'مثال ${i + 1}' : 'Example ${i + 1}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
