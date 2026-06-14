import 'dart:convert';
import 'package:flutter/services.dart';

/// A single disease entry from the local JSON asset.
class LocalDisease {
  const LocalDisease({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.scientificName,
    required this.cropEn,
    required this.cropAr,
    required this.symptomsEn,
    required this.symptomsAr,
    required this.treatmentEn,
    required this.treatmentAr,
    required this.severity,
  });

  final String id;
  final String nameEn;
  final String nameAr;
  final String scientificName;
  final String cropEn;
  final String cropAr;
  final String symptomsEn;
  final String symptomsAr;
  final String treatmentEn;
  final String treatmentAr;
  final String severity;

  factory LocalDisease.fromJson(Map<String, dynamic> json) {
    return LocalDisease(
      id: json['id']?.toString() ?? '',
      nameEn: json['nameEn']?.toString() ?? '',
      nameAr: json['nameAr']?.toString() ?? '',
      scientificName: json['scientificName']?.toString() ?? '',
      cropEn: json['cropEn']?.toString() ?? '',
      cropAr: json['cropAr']?.toString() ?? '',
      symptomsEn: json['symptomsEn']?.toString() ?? '',
      symptomsAr: json['symptomsAr']?.toString() ?? '',
      treatmentEn: json['treatmentEn']?.toString() ?? '',
      treatmentAr: json['treatmentAr']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'low',
    );
  }
}

/// Singleton that loads diseases.json once and provides lookup methods.
class DiseaseLocalDb {
  DiseaseLocalDb._();
  static final DiseaseLocalDb instance = DiseaseLocalDb._();

  List<LocalDisease>? _diseases;

  Future<List<LocalDisease>> all() async {
    _diseases ??= await _load();
    return _diseases!;
  }

  /// Find by English or Arabic name (case-insensitive partial match).
  Future<LocalDisease?> findByName(String name) async {
    final list = await all();
    final query = name.toLowerCase();
    try {
      return list.firstWhere(
        (d) =>
            d.nameEn.toLowerCase().contains(query) ||
            d.nameAr.contains(name),
      );
    } catch (_) {
      return null;
    }
  }

  /// Find by disease ID.
  Future<LocalDisease?> findById(String id) async {
    final list = await all();
    try {
      return list.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<LocalDisease>> _load() async {
    final raw = await rootBundle.loadString('assets/data/diseases.json');
    final decoded = json.decode(raw) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(LocalDisease.fromJson)
        .toList();
  }
}
