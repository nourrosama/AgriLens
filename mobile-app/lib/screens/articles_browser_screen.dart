import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:agrilens/core/disease_articles_service.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';

// ─── Crop metadata ────────────────────────────────────────────────────────────

class _CropMeta {
  const _CropMeta({
    required this.key,
    required this.nameEn,
    required this.nameAr,
    required this.emoji,
  });
  final String key;
  final String nameEn;
  final String nameAr;
  final String emoji;
}

const List<_CropMeta> _crops = [
  _CropMeta(key: 'wheat',     nameEn: 'Wheat',     nameAr: 'القمح',         emoji: '🌾'),
  _CropMeta(key: 'tomato',    nameEn: 'Tomato',    nameAr: 'الطماطم',       emoji: '🍅'),
  _CropMeta(key: 'potato',    nameEn: 'Potato',    nameAr: 'البطاطس',       emoji: '🥔'),
  _CropMeta(key: 'corn',      nameEn: 'Corn',      nameAr: 'الذرة',         emoji: '🌽'),
  _CropMeta(key: 'sugarcane', nameEn: 'Sugarcane', nameAr: 'قصب السكر',     emoji: '🎋'),
  _CropMeta(key: 'grape',     nameEn: 'Grape',     nameAr: 'العنب',         emoji: '🍇'),
  _CropMeta(key: 'apple',     nameEn: 'Apple',     nameAr: 'التفاح',        emoji: '🍎'),
  _CropMeta(key: 'cotton',    nameEn: 'Cotton',    nameAr: 'القطن',         emoji: '🌸'),
];

// ─── Disease display names ────────────────────────────────────────────────────

final _diseaseNamesAr = <String, String>{
  'aphid': 'حشرة المن',
  'black_rust': 'الصدأ الأسود',
  'blast': 'الانفجار',
  'brown_rust': 'الصدأ البني',
  'common_root_rot': 'تعفن الجذور الشائع',
  'fusarium_head_blight': 'لفحة السنبلة الفيوزاريومية',
  'healthy': 'نبات سليم',
  'leaf_blight': 'لفحة الأوراق',
  'mildew': 'البياض الدقيقي',
  'mite': 'الأكاروسات',
  'septoria': 'السبتوريا',
  'smut': 'التفحم',
  'stem_fly': 'ذبابة الساق',
  'tan_spot': 'البقعة التانية',
  'yellow_rust': 'الصدأ الأصفر',
  'bacterial_spot': 'اللفحة البكتيرية',
  'early_blight': 'اللفحة المبكرة',
  'late_blight': 'اللفحة المتأخرة',
  'leaf_mold': 'عفن الأوراق',
  'septoria_leaf_spot': 'تبقع سبتوريا الأوراق',
  'spider_mites': 'أكاروسات العنكبوت',
  'target_spot': 'البقعة المستهدفة',
  'tomato_yellow_leaf_curl_virus': 'فيروس تجعد الأوراق الأصفر',
  'tomato_mosaic_virus': 'فيروس الموزاييك',
  'mosaic': 'الموزاييك',
  'redrot': 'التعفن الأحمر',
  'rust': 'الصدأ',
  'yellow': 'الاصفرار',
  'bacteria': 'الأمراض البكتيرية',
  'fungi': 'الأمراض الفطرية',
  'nematode': 'النيماتودا',
  'pest': 'الآفات',
  'phytophthora': 'الفيتوفثورا',
  'virus': 'الفيروسات',
  'bacterial_rot': 'التعفن البكتيري',
  'black_rot': 'التعفن الأسود',
  'downey_mildew': 'البياض الزغبي',
  'esca_black_measles': 'مرض الإسكا',
  'powdery_mildew': 'البياض الدقيقي',
  'bacterial_blight': 'اللفحة البكتيرية',
  'curl_virus': 'فيروس التجعد',
  'fussarium_wilt': 'الذبول الفيوزاريومي',
  'blight': 'اللفحة',
  'common_rust': 'الصدأ الشائع',
  'gray_leaf_spot': 'البقعة الرمادية',
  'apple_scab': 'جرب التفاح',
  'cedar_apple_rust': 'صدأ التفاح والعرعر',
};

String _diseaseDisplayEn(String key) => key
    .split('_')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _diseaseDisplayAr(String key) =>
    _diseaseNamesAr[key] ?? _diseaseDisplayEn(key);

// ─── Screen ───────────────────────────────────────────────────────────────────

class ArticlesBrowserScreen extends StatefulWidget {
  const ArticlesBrowserScreen({super.key});

  @override
  State<ArticlesBrowserScreen> createState() => _ArticlesBrowserScreenState();
}

class _ArticlesBrowserScreenState extends State<ArticlesBrowserScreen> {
  Map<String, Map<String, List<DiseaseArticle>>> _data = {};
  bool _loading = true;

  // Tracks which crop is expanded
  String? _expandedCrop;
  // Tracks which disease card is expanded within the crop
  String? _expandedDisease;

  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase().trim());
    });
  }

  Future<void> _load() async {
    final data = await DiseaseArticlesService.getAllCropDiseases();
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRTL = lang.isRTL;

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
          isRTL ? 'مقالات الأمراض' : 'Disease Articles',
          style: const TextStyle(
              color: AppColors.primaryDark, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Search bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchCtrl,
                    textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: isRTL
                          ? 'ابحث عن محصول أو مرض…'
                          : 'Search crop or disease…',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textSecondary),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                              child: const Icon(Icons.close_rounded,
                                  color: AppColors.textSecondary))
                          : null,
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
                const Divider(height: 1),

                // Content
                Expanded(
                  child: _query.isNotEmpty
                      ? _SearchResults(
                          data: _data,
                          query: _query,
                          isRTL: isRTL,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: _crops.length,
                          itemBuilder: (_, i) {
                            final crop = _crops[i];
                            final cropData = _data[crop.key];
                            if (cropData == null || cropData.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final isExpanded = _expandedCrop == crop.key;
                            return _CropSection(
                              crop: crop,
                              diseases: cropData,
                              isExpanded: isExpanded,
                              expandedDisease: isExpanded ? _expandedDisease : null,
                              isRTL: isRTL,
                              onCropTap: () => setState(() {
                                _expandedCrop =
                                    isExpanded ? null : crop.key;
                                _expandedDisease = null;
                              }),
                              onDiseaseTap: (diseaseKey) => setState(() {
                                _expandedDisease =
                                    _expandedDisease == diseaseKey
                                        ? null
                                        : diseaseKey;
                              }),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ─── Crop section (expandable) ────────────────────────────────────────────────

class _CropSection extends StatelessWidget {
  const _CropSection({
    required this.crop,
    required this.diseases,
    required this.isExpanded,
    required this.expandedDisease,
    required this.isRTL,
    required this.onCropTap,
    required this.onDiseaseTap,
  });

  final _CropMeta crop;
  final Map<String, List<DiseaseArticle>> diseases;
  final bool isExpanded;
  final String? expandedDisease;
  final bool isRTL;
  final VoidCallback onCropTap;
  final ValueChanged<String> onDiseaseTap;

  @override
  Widget build(BuildContext context) {
    // Skip 'healthy' unless it's the only disease
    final diseaseKeys = diseases.keys
        .where((k) => k != 'healthy' || diseases.length == 1)
        .toList()
      ..sort();

    // Total article count
    final totalArticles = diseases.values
        .fold<int>(0, (sum, list) => sum + list.length);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? AppColors.primary.withValues(alpha: 0.4)
              : const Color(0xFFE0E0E0),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                )
              ]
            : [],
      ),
      child: Column(
        children: [
          // Crop header
          GestureDetector(
            onTap: onCropTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(crop.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRTL ? crop.nameAr : crop.nameEn,
                          style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isRTL
                              ? '${diseaseKeys.length} مرض  •  $totalArticles مقال'
                              : '${diseaseKeys.length} diseases  •  $totalArticles articles',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // Disease list (animated)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1),
                ...diseaseKeys.map((dKey) {
                  final articles = diseases[dKey] ?? [];
                  final isDiseaseExpanded = expandedDisease == dKey;
                  return _DiseaseItem(
                    diseaseKey: dKey,
                    articles: articles,
                    isExpanded: isDiseaseExpanded,
                    isRTL: isRTL,
                    onTap: () => onDiseaseTap(dKey),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Disease item (expandable) ────────────────────────────────────────────────

class _DiseaseItem extends StatelessWidget {
  const _DiseaseItem({
    required this.diseaseKey,
    required this.articles,
    required this.isExpanded,
    required this.isRTL,
    required this.onTap,
  });

  final String diseaseKey;
  final List<DiseaseArticle> articles;
  final bool isExpanded;
  final bool isRTL;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            color: isExpanded
                ? const Color(0xFFF1F8E9)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isExpanded
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.bug_report_outlined,
                    color: isExpanded
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRTL
                            ? _diseaseDisplayAr(diseaseKey)
                            : _diseaseDisplayEn(diseaseKey),
                        style: TextStyle(
                          color: isExpanded
                              ? AppColors.primaryDark
                              : const Color(0xFF424242),
                          fontSize: 14,
                          fontWeight: isExpanded
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                      Text(
                        isRTL
                            ? '${articles.length} مقال'
                            : '${articles.length} article${articles.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isExpanded
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Articles
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: articles
                .map((a) => _ArticleLink(article: a, isRTL: isRTL))
                .toList(),
          ),
        ),

        const Divider(height: 1, indent: 16),
      ],
    );
  }
}

// ─── Article link tile ────────────────────────────────────────────────────────

class _ArticleLink extends StatelessWidget {
  const _ArticleLink({required this.article, required this.isRTL});
  final DiseaseArticle article;
  final bool isRTL;

  Future<void> _open() async {
    final uri = Uri.tryParse(article.url);
    if (uri == null || article.url.isEmpty) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = isRTL && article.titleAr.isNotEmpty
        ? article.titleAr
        : article.title;

    return InkWell(
      onTap: _open,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 46), // indent under disease icon
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.link_rounded,
                          size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          article.source,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.open_in_new,
                          size: 12,
                          color: AppColors.textSecondary),
                    ],
                  ),
                  if (article.summary.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      article.summary,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search results ───────────────────────────────────────────────────────────

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.data,
    required this.query,
    required this.isRTL,
  });

  final Map<String, Map<String, List<DiseaseArticle>>> data;
  final String query;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    final results = <_SearchHit>[];

    for (final cropEntry in data.entries) {
      final cropMeta = _crops.firstWhere(
        (c) => c.key == cropEntry.key,
        orElse: () => _CropMeta(
            key: cropEntry.key,
            nameEn: cropEntry.key,
            nameAr: cropEntry.key,
            emoji: '🌿'),
      );

      for (final diseaseEntry in cropEntry.value.entries) {
        final diseaseEn = _diseaseDisplayEn(diseaseEntry.key);
        final diseaseAr = _diseaseDisplayAr(diseaseEntry.key);

        for (final article in diseaseEntry.value) {
          final searchText =
              '${cropMeta.nameEn} ${cropMeta.nameAr} $diseaseEn $diseaseAr ${article.title} ${article.titleAr} ${article.summary} ${article.source}'
                  .toLowerCase();

          if (searchText.contains(query)) {
            results.add(_SearchHit(
              cropMeta: cropMeta,
              diseaseKey: diseaseEntry.key,
              article: article,
            ));
          }
        }
      }
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 56, color: Color(0xFFBDBDBD)),
            const SizedBox(height: 12),
            Text(
              isRTL ? 'لا نتائج' : 'No results',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final hit = results[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8F5E9)),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(hit.cropMeta.emoji,
                    style: const TextStyle(fontSize: 22)),
              ],
            ),
            title: Text(
              isRTL && hit.article.titleAr.isNotEmpty
                  ? hit.article.titleAr
                  : hit.article.title,
              style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  '${isRTL ? hit.cropMeta.nameAr : hit.cropMeta.nameEn}  ›  ${isRTL ? _diseaseDisplayAr(hit.diseaseKey) : _diseaseDisplayEn(hit.diseaseKey)}',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  hit.article.source,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
            trailing: const Icon(Icons.open_in_new,
                size: 16, color: AppColors.textSecondary),
            onTap: () async {
              final uri = Uri.tryParse(hit.article.url);
              if (uri == null || hit.article.url.isEmpty) return;
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
          ),
        );
      },
    );
  }
}

class _SearchHit {
  const _SearchHit({
    required this.cropMeta,
    required this.diseaseKey,
    required this.article,
  });
  final _CropMeta cropMeta;
  final String diseaseKey;
  final DiseaseArticle article;
}
