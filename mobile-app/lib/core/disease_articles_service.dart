import 'dart:convert';
import 'package:flutter/services.dart';

class DiseaseArticle {
  const DiseaseArticle({
    required this.title,
    required this.titleAr,
    required this.source,
    required this.url,
    required this.summary,
  });

  final String title;
  final String titleAr;
  final String source;
  final String url;
  final String summary;

  factory DiseaseArticle.fromJson(Map<String, dynamic> j) => DiseaseArticle(
        title: j['title']?.toString() ?? '',
        titleAr: j['title_ar']?.toString() ?? '',
        source: j['source']?.toString() ?? '',
        url: j['url']?.toString() ?? '',
        summary: j['summary']?.toString() ?? '',
      );
}

class DiseaseArticlesService {
  static Map<String, dynamic>? _data;

  static Future<void> _load() async {
    if (_data != null) return;
    final raw = await rootBundle.loadString('assets/data/disease_articles.json');
    _data = json.decode(raw) as Map<String, dynamic>;
  }

  /// Returns 4-5 curated articles for [crop] + [disease].
  /// Falls back to the "healthy" articles for that crop, then empty list.
  static Future<List<DiseaseArticle>> getArticles({
    required String crop,
    required String disease,
  }) async {
    await _load();

    final cropKey = _normalise(crop);
    final diseaseKey = _normalise(disease);

    final cropMap = _data?[cropKey] as Map<String, dynamic>?;
    if (cropMap == null) return [];

    // Try exact disease key first
    List<dynamic>? raw = cropMap[diseaseKey] as List<dynamic>?;

    // Fallback: try partial match (e.g. "early_blight" inside key names)
    if (raw == null) {
      for (final key in cropMap.keys) {
        if (key.contains(diseaseKey) || diseaseKey.contains(key)) {
          raw = cropMap[key] as List<dynamic>?;
          break;
        }
      }
    }

    // Last resort: healthy articles for the crop
    raw ??= cropMap['healthy'] as List<dynamic>? ?? [];

    return raw
        .map((e) => DiseaseArticle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns the full data map: crop → disease → articles
  static Future<Map<String, Map<String, List<DiseaseArticle>>>> getAllCropDiseases() async {
    await _load();
    final result = <String, Map<String, List<DiseaseArticle>>>{};
    for (final cropEntry in (_data ?? {}).entries) {
      final cropKey = cropEntry.key;
      final diseaseMap = cropEntry.value as Map<String, dynamic>;
      result[cropKey] = {};
      for (final diseaseEntry in diseaseMap.entries) {
        final raw = diseaseEntry.value as List<dynamic>;
        result[cropKey]![diseaseEntry.key] = raw
            .map((e) => DiseaseArticle.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return result;
  }

  static String _normalise(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-]+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');
}
