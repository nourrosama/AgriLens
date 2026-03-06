import 'package:flutter/material.dart';

/// Scan result data model
class ScanResult {
  final int id;
  final String imagePath;
  final String diseaseNameEn;
  final String diseaseNameAr;
  final String scientificName;
  final double confidence;
  final String severity; // 'low', 'medium', 'high'
  final DateTime scannedAt;
  final String? fieldName;

  ScanResult({
    required this.id,
    required this.imagePath,
    required this.diseaseNameEn,
    required this.diseaseNameAr,
    required this.scientificName,
    required this.confidence,
    required this.severity,
    DateTime? scannedAt,
    this.fieldName,
  }) : scannedAt = scannedAt ?? DateTime.now();
}

/// Provider that manages scan history.
/// Ready to connect to backend — see TODO comments for API integration points.
class ScanHistoryProvider extends ChangeNotifier {
  int _nextId = 4;

  final List<ScanResult> _scans = [
    ScanResult(
      id: 1,
      imagePath: '',
      diseaseNameEn: 'Late Blight',
      diseaseNameAr: 'اللفحة المتأخرة',
      scientificName: 'Phytophthora infestans',
      confidence: 0.92,
      severity: 'medium',
      scannedAt: DateTime.now().subtract(const Duration(days: 1)),
      fieldName: 'Field A',
    ),
    ScanResult(
      id: 2,
      imagePath: '',
      diseaseNameEn: 'Early Blight',
      diseaseNameAr: 'اللفحة المبكرة',
      scientificName: 'Alternaria solani',
      confidence: 0.87,
      severity: 'low',
      scannedAt: DateTime.now().subtract(const Duration(days: 3)),
      fieldName: 'Field B',
    ),
    ScanResult(
      id: 3,
      imagePath: '',
      diseaseNameEn: 'Leaf Spot',
      diseaseNameAr: 'بقع الأوراق',
      scientificName: 'Septoria lycopersici',
      confidence: 0.95,
      severity: 'high',
      scannedAt: DateTime.now().subtract(const Duration(days: 5)),
      fieldName: 'Field C',
    ),
  ];

  List<ScanResult> get scans => List.unmodifiable(_scans);
  int get totalScans => _scans.length;
  int get activeDiseasesCount => _scans.where((s) => s.severity == 'high' || s.severity == 'medium').length;

  /// Weekly scan counts (last 7 days)
  List<int> get weeklyScans {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return _scans.where((s) =>
          s.scannedAt.year == day.year &&
          s.scannedAt.month == day.month &&
          s.scannedAt.day == day.day).length;
    });
  }

  /// TODO: Replace with API call to POST /api/detect
  void addScan({
    required String imagePath,
    String diseaseNameEn = 'Late Blight',
    String diseaseNameAr = 'اللفحة المتأخرة',
    String scientificName = 'Phytophthora infestans',
    double confidence = 0.92,
    String severity = 'medium',
    String? fieldName,
  }) {
    _scans.insert(0, ScanResult(
      id: _nextId++,
      imagePath: imagePath,
      diseaseNameEn: diseaseNameEn,
      diseaseNameAr: diseaseNameAr,
      scientificName: scientificName,
      confidence: confidence,
      severity: severity,
      fieldName: fieldName,
    ));
    notifyListeners();
  }

  /// TODO: Replace with API call to GET /api/scans/:id
  ScanResult? getScan(int id) {
    try {
      return _scans.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
