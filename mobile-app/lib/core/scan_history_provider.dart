import 'dart:io';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_config.dart';
import 'offline_queue_store.dart';

class ScanPrediction {
  ScanPrediction({
    required this.classId,
    required this.label,
    required this.disease,
    required this.confidence,
  });

  final int classId;
  final String label;
  final String disease;
  final double confidence;

  factory ScanPrediction.fromJson(Map<String, dynamic> json) {
    return ScanPrediction(
      classId: (json['class_id'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString() ?? '',
      disease: json['disease']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ScanResult {
  ScanResult({
    required this.id,
    required this.farmId,
    required this.fieldId,
    required this.imagePath,
    required this.diseaseNameEn,
    required this.diseaseNameAr,
    required this.scientificName,
    required this.confidence,
    required this.severity,
    required this.status,
    required this.scannedAt,
    required this.isHealthy,
    required this.riskLevel,
    required this.recommendation,
    required this.modelVersion,
    required this.mediaType,
    required this.hasDetection,
    this.storageBackend = 'local',
    this.fieldName,
    this.cropType = '',
    this.remoteImageUrl,
    this.topPredictions = const [],
  });

  final String id;
  final String? farmId;
  final String? fieldId;
  final String imagePath;
  final String diseaseNameEn;
  final String diseaseNameAr;
  final String scientificName;
  final double confidence;
  final String severity;
  final String status;
  final DateTime scannedAt;
  final bool isHealthy;
  final String riskLevel;
  final String recommendation;
  final String modelVersion;
  final String? fieldName;
  final String cropType;
  final String? remoteImageUrl;
  final String mediaType;
  final bool hasDetection;
  final String storageBackend;
  final List<ScanPrediction> topPredictions;

  bool get isVideo => mediaType == 'video';
  bool get isStoredInFirebase => storageBackend == 'firebase';

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final detection =
        (json['detection_result'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    final mediaType = json['media_type']?.toString() ?? 'image';
    final imageUrl = json['image_url']?.toString() ?? '';
    final resolvedImageUrl = imageUrl.isEmpty
        ? null
        : AppConfig.resolveMediaUrl(imageUrl);
    final hasDetection = detection.isNotEmpty;

    final fallbackName = mediaType == 'video'
        ? 'Video uploaded'
        : 'Analysis pending';
    final diseaseName = detection['disease']?.toString() ?? fallbackName;

    return ScanResult(
      id: json['id']?.toString() ?? '',
      farmId: json['farm_id']?.toString(),
      fieldId: json['field_id']?.toString(),
      imagePath: resolvedImageUrl ?? imageUrl,
      diseaseNameEn: diseaseName,
      diseaseNameAr: diseaseName,
      scientificName: detection['scientific_name']?.toString() ?? '',
      confidence: (detection['confidence'] as num?)?.toDouble() ?? 0,
      severity: detection['severity']?.toString() ?? 'none',
      status: json['status']?.toString() ?? 'pending',
      scannedAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isHealthy: detection['is_healthy'] == true,
      riskLevel: detection['risk_level']?.toString() ?? 'low',
      recommendation: detection['recommendation']?.toString() ?? '',
      modelVersion: detection['model_version']?.toString() ?? '',
      cropType: json['crop_type']?.toString() ?? '',
      remoteImageUrl: resolvedImageUrl,
      mediaType: mediaType,
      hasDetection: hasDetection,
      storageBackend: json['storage_backend']?.toString() ?? 'local',
      topPredictions: ((detection['top_predictions'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ScanPrediction.fromJson)
          .toList(),
    );
  }
}

class ScanHistoryProvider extends ChangeNotifier {
  ScanHistoryProvider({ApiClient? apiClient, OfflineQueueStore? queueStore})
    : _apiClient = apiClient ?? ApiClient(),
      _queueStore = queueStore ?? OfflineQueueStore() {
    loadScans();
  }

  final ApiClient _apiClient;
  final OfflineQueueStore _queueStore;
  final List<ScanResult> _scans = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ScanResult> get scans => List.unmodifiable(_scans);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalScans => _scans.length;
  int get activeDiseasesCount => _scans
      .where(
        (scan) =>
            scan.hasDetection &&
            (scan.severity == 'high' || scan.severity == 'medium'),
      )
      .length;

  List<int> get weeklyScans {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      return _scans.where((scan) {
        return scan.scannedAt.year == day.year &&
            scan.scannedAt.month == day.month &&
            scan.scannedAt.day == day.day;
      }).length;
    });
  }

  Future<void> loadScans() async {
    _setLoading(true);
    try {
      final response = await _apiClient.get('/api/scans', auth: true);
      final items =
          ((response['data'] as Map<String, dynamic>)['scans']
                      as List<dynamic>? ??
                  [])
              .whereType<Map<String, dynamic>>()
              .toList();
      _scans
        ..clear()
        ..addAll(items.map(ScanResult.fromJson));
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<ScanResult?> submitScan({
    required File imageFile,
    required String cropType,
    String? farmId,
    String? fieldId,
  }) async {
    return _submitMedia(
      file: imageFile,
      mediaType: 'image',
      cropType: cropType,
      farmId: farmId,
      fieldId: fieldId,
    );
  }

  Future<ScanResult?> submitVideoScan({
    required File videoFile,
    required String cropType,
    String? farmId,
    String? fieldId,
  }) async {
    return _submitMedia(
      file: videoFile,
      mediaType: 'video',
      cropType: cropType,
      farmId: farmId,
      fieldId: fieldId,
    );
  }

  Future<ScanResult?> _submitMedia({
    required File file,
    required String mediaType,
    required String cropType,
    String? farmId,
    String? fieldId,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.multipart(
        '/api/scans',
        auth: true,
        fieldName: mediaType == 'video' ? 'video' : 'image',
        file: file,
        fields: {
          'crop_type': cropType,
          ...?(farmId == null ? null : {'farm_id': farmId}),
          ...?(fieldId == null ? null : {'field_id': fieldId}),
          'device_type': 'mobile',
          'app_version': '1.0.0',
        },
      );
      final scanJson =
          (response['data'] as Map<String, dynamic>)['scan']
              as Map<String, dynamic>;
      final scan = ScanResult.fromJson(scanJson);
      _upsertScan(scan);
      _errorMessage = null;
      notifyListeners();
      return scan;
    } catch (error) {
      if (mediaType == 'image') {
        await _queueStore.enqueueScan(
          imageFile: file,
          cropType: cropType,
          farmId: farmId,
          fieldId: fieldId,
        );
      }
      _errorMessage = error.toString();
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> syncQueuedScans() async {
    final queued = await _queueStore.listQueuedScans();
    for (final item in queued) {
      final file = File(item.imagePath);
      if (!file.existsSync()) {
        await _queueStore.removeQueuedScan(item.id);
        continue;
      }
      final scan = await submitScan(
        imageFile: file,
        cropType: item.cropType,
        farmId: item.farmId,
        fieldId: item.fieldId,
      );
      if (scan != null) {
        await _queueStore.removeQueuedScan(item.id);
      }
    }
  }

  Future<ScanResult?> getScan(String id) async {
    try {
      final cached = _scans.where((scan) => scan.id == id);
      if (cached.isNotEmpty) {
        return cached.first;
      }
      final response = await _apiClient.get('/api/scans/$id', auth: true);
      final scanJson =
          (response['data'] as Map<String, dynamic>)['scan']
              as Map<String, dynamic>;
      final scan = ScanResult.fromJson(scanJson);
      _upsertScan(scan);
      notifyListeners();
      return scan;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return null;
    }
  }

  void _upsertScan(ScanResult scan) {
    _scans.removeWhere((item) => item.id == scan.id);
    _scans.insert(0, scan);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
