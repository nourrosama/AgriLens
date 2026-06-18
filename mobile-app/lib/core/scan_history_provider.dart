import 'dart:io' as io;
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'app_config.dart';
import 'fcm_service.dart';
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

class SelectedVideoFrame {
  SelectedVideoFrame({
    required this.frameIndex,
    required this.frameUrl,
    required this.displayUrl,
    required this.disease,
    required this.confidence,
    required this.severity,
    required this.riskLevel,
    required this.isHealthy,
    this.gradcamUrl,
    this.keyframeScore,
  });

  final int frameIndex;
  final String frameUrl;
  final String displayUrl;
  final String disease;
  final double confidence;
  final String severity;
  final String riskLevel;
  final bool isHealthy;
  final String? gradcamUrl;
  final double? keyframeScore;

  bool get hasGradcam => gradcamUrl != null && gradcamUrl!.isNotEmpty;

  factory SelectedVideoFrame.fromJson(Map<String, dynamic> json) {
    final frameUrl = AppConfig.resolveMediaUrl(json['frame_url']?.toString() ?? '');
    final gradcamRaw = json['gradcam_url']?.toString() ?? '';
    final gradcamUrl = gradcamRaw.isEmpty ? null : AppConfig.resolveMediaUrl(gradcamRaw);
    final displayRaw = json['display_url']?.toString() ?? '';
    final displayUrl = displayRaw.isNotEmpty
        ? AppConfig.resolveMediaUrl(displayRaw)
        : (gradcamUrl ?? frameUrl);

    return SelectedVideoFrame(
      frameIndex: (json['frame_index'] as num?)?.toInt() ?? 0,
      keyframeScore: (json['keyframe_score'] as num?)?.toDouble(),
      frameUrl: frameUrl,
      gradcamUrl: gradcamUrl,
      displayUrl: displayUrl,
      disease: json['disease']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      severity: json['severity']?.toString() ?? 'none',
      riskLevel: json['risk_level']?.toString() ?? 'low',
      isHealthy: json['is_healthy'] == true,
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
    this.remoteMediaUrl,
    this.topPredictions = const [],
    this.selectedFrames = const [],
    this.gradcamOverlay,
    this.diseaseReport,
    this.localImageBytes,
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
  final String? remoteMediaUrl;
  final String mediaType;
  final bool hasDetection;
  final String storageBackend;
  final List<ScanPrediction> topPredictions;
  final List<SelectedVideoFrame> selectedFrames;

  /// Base64-encoded PNG of the Grad-CAM heatmap overlay.
  /// Only present in the immediate scan creation response; null for history.
  final String? gradcamOverlay;

  /// Structured AI disease report fetched from /api/disease-report.
  /// Populated lazily by ScanResultScreen; null until fetched.
  final Map<String, dynamic>? diseaseReport;

  /// Raw bytes of the uploaded image, cached at scan-creation time so the
  /// GradCAM overlay can be rendered instantly without a second network trip.
  /// Null for scans loaded from history.
  final Uint8List? localImageBytes;

  bool get isVideo => mediaType == 'video';
  bool get isStoredRemotely => storageBackend != 'local';

  /// Returns a copy of this scan with [bytes] attached as [localImageBytes].
  ScanResult withLocalImageBytes(Uint8List bytes) => ScanResult(
    id: id,
    farmId: farmId,
    fieldId: fieldId,
    imagePath: imagePath,
    diseaseNameEn: diseaseNameEn,
    diseaseNameAr: diseaseNameAr,
    scientificName: scientificName,
    confidence: confidence,
    severity: severity,
    status: status,
    scannedAt: scannedAt,
    isHealthy: isHealthy,
    riskLevel: riskLevel,
    recommendation: recommendation,
    modelVersion: modelVersion,
    mediaType: mediaType,
    hasDetection: hasDetection,
    storageBackend: storageBackend,
    fieldName: fieldName,
    cropType: cropType,
    remoteMediaUrl: remoteMediaUrl,
    topPredictions: topPredictions,
    selectedFrames: selectedFrames,
    gradcamOverlay: gradcamOverlay,
    diseaseReport: diseaseReport,
    localImageBytes: bytes,
  );

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final detection =
        (json['detection_result'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    final mediaType = json['media_type']?.toString() ?? 'image';
    final mediaUrl =
        json['media_url']?.toString() ?? json['image_url']?.toString() ?? '';
    final resolvedMediaUrl = mediaUrl.isEmpty
        ? null
        : AppConfig.resolveMediaUrl(mediaUrl);
    final hasDetection = detection.isNotEmpty;

    final fallbackName = mediaType == 'video'
        ? 'Video uploaded'
        : 'Analysis pending';
    final diseaseName = detection['disease']?.toString() ?? fallbackName;

    return ScanResult(
      id: json['id']?.toString() ?? '',
      farmId: json['farm_id']?.toString(),
      fieldId: json['field_id']?.toString(),
      imagePath: resolvedMediaUrl ?? mediaUrl,
      diseaseNameEn: diseaseName,
      diseaseNameAr: diseaseName,
      scientificName: detection['scientific_name']?.toString() ?? '',
      confidence: (detection['confidence'] as num?)?.toDouble() ?? 0,
      severity: detection['severity']?.toString() ?? 'none',
      status: json['status']?.toString() ?? 'pending',
      scannedAt: () {
        // Server returns UTC without a Z suffix (e.g. "2025-06-16T10:00:00").
        // Without the Z, Dart treats it as local time, so Egypt (UTC+3) scans
        // appear 3 hours older than they are. Same fix as notifications_provider.
        String ts = json['created_at']?.toString() ?? '';
        if (ts.isNotEmpty &&
            !ts.endsWith('Z') &&
            !RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(ts)) {
          ts += 'Z';
        }
        return (ts.isEmpty ? null : DateTime.tryParse(ts)?.toLocal()) ??
            DateTime.now();
      }(),
      isHealthy: detection['is_healthy'] == true,
      riskLevel: detection['risk_level']?.toString() ?? 'low',
      recommendation: detection['recommendation']?.toString() ?? '',
      modelVersion: detection['model_version']?.toString() ?? '',
      cropType: json['crop_type']?.toString() ?? '',
      remoteMediaUrl: resolvedMediaUrl,
      mediaType: mediaType,
      hasDetection: hasDetection,
      storageBackend: json['storage_backend']?.toString() ?? 'local',
      topPredictions: ((detection['top_predictions'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ScanPrediction.fromJson)
          .toList(),
      selectedFrames: ((detection['selected_frames'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SelectedVideoFrame.fromJson)
          .toList(),
      gradcamOverlay: detection['gradcam_overlay']?.toString(),
    );
  }
}

class ScanValidationFailure {
  ScanValidationFailure({
    required this.errorCode,
    required this.message,
    required this.selectedCrop,
    required this.detectedCrop,
    required this.supportedCrops,
    this.scan,
  });

  final String errorCode;
  final String message;
  final String selectedCrop;
  final String detectedCrop;
  final List<String> supportedCrops;
  final ScanResult? scan;

  bool get canUseDetectedCrop {
    return errorCode == 'CROP_MISMATCH' &&
        detectedCrop.isNotEmpty &&
        detectedCrop != 'unknown_plant' &&
        supportedCrops.contains(detectedCrop);
  }

  factory ScanValidationFailure.fromApiException(ApiException error) {
    final validation = error.validation ?? error.body ?? <String, dynamic>{};
    final data = error.data ?? <String, dynamic>{};
    final scanJson = data['scan'];
    return ScanValidationFailure(
      errorCode:
          validation['error_code']?.toString() ??
          error.errorCode ??
          'VALIDATION_FAILED',
      message:
          validation['message']?.toString() ??
          validation['error']?.toString() ??
          error.message,
      selectedCrop: validation['selected_crop']?.toString() ?? '',
      detectedCrop: validation['detected_crop']?.toString() ?? '',
      supportedCrops: ((validation['supported_crops'] as List<dynamic>?) ?? [])
          .map((item) => item.toString())
          .toList(),
      scan: scanJson is Map<String, dynamic>
          ? ScanResult.fromJson(scanJson)
          : null,
    );
  }
}

class ScanHistoryProvider extends ChangeNotifier {
  ScanHistoryProvider({ApiClient? apiClient, OfflineQueueStore? queueStore})
    : _apiClient = apiClient ?? ApiClient(),
      _queueStore = queueStore ?? OfflineQueueStore();

  final ApiClient _apiClient;
  final OfflineQueueStore _queueStore;
  final List<ScanResult> _scans = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentUserId = '';
  ScanValidationFailure? _validationFailure;

  List<ScanResult> get scans => List.unmodifiable(_scans);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ScanValidationFailure? get validationFailure => _validationFailure;
  int get totalScans => _scans.length;
  String get currentUserId => _currentUserId;

  void clear() {
    _scans.clear();
    _errorMessage = null;
    notifyListeners();
  }

  /// Called by the proxy provider in main.dart whenever the logged-in user changes.
  void onUserChanged(String userId) {
    if (userId == _currentUserId) return;
    _currentUserId = userId;
    if (userId.isEmpty) {
      clear();
    } else {
      loadScans();
    }
  }

  // Number of scans waiting to be synced while offline.
  int _queuedCount = 0;
  int get queuedCount => _queuedCount;

  Future<void> _refreshQueuedCount() async {
    final queued = await _queueStore.listQueuedScans();
    _queuedCount = queued.length;
    notifyListeners();
  }
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

  Future<void> loadScans({
    String? farmId,
    String? fieldId,
    String? cropType,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.get(
        '/api/scans',
        auth: true,
        query: {
          ...?(farmId == null ? null : {'farm_id': farmId}),
          ...?(fieldId == null ? null : {'field_id': fieldId}),
          ...?(cropType == null || cropType.isEmpty
              ? null
              : {'crop_type': cropType}),
        },
      );
      final items =
          ((response['data'] as Map<String, dynamic>)['scans']
                      as List<dynamic>? ??
                  [])
              .whereType<Map<String, dynamic>>()
              .toList();
      final loadedScans = items.map(ScanResult.fromJson).toList();
      if (farmId == null &&
          fieldId == null &&
          (cropType == null || cropType.isEmpty)) {
        _scans
          ..clear()
          ..addAll(loadedScans);
      } else {
        if (fieldId != null) {
          _scans.removeWhere((scan) => scan.fieldId == fieldId);
        } else if (farmId != null) {
          _scans.removeWhere((scan) => scan.farmId == farmId);
        }
        for (final scan in loadedScans.reversed) {
          _upsertScan(scan);
        }
      }
      _errorMessage = null;
      _validationFailure = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<ScanResult?> submitScan({
    io.File? imageFile,
    Uint8List? imageBytes,
    String? imageName,
    required String cropType,
    String? farmId,
    String? fieldId,
  }) async {
    if (kIsWeb && imageBytes != null) {
      return _submitMediaWeb(
        bytes: imageBytes,
        filename: imageName ?? 'scan.jpg',
        mediaType: 'image',
        cropType: cropType,
        farmId: farmId,
        fieldId: fieldId,
      );
    }
    return _submitMedia(
      file: imageFile!,
      mediaType: 'image',
      cropType: cropType,
      farmId: farmId,
      fieldId: fieldId,
    );
  }

  Future<ScanResult?> submitVideoScan({
    required io.File videoFile,
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
    required io.File file,
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
        timeout: const Duration(seconds: 90), // upload only; video processing is async

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
      var scan = ScanResult.fromJson(scanJson);
      // Cache image bytes so the GradCAM card can render instantly without
      // a second network request (bytes are already in memory here).
      if (mediaType == 'image' && !kIsWeb) {
        try {
          final bytes = await file.readAsBytes();
          scan = scan.withLocalImageBytes(bytes);
        } catch (_) {
          // Reading bytes is best-effort; silently skip if it fails.
        }
      }
      _upsertScan(scan);
      _errorMessage = null;
      _validationFailure = null;
      notifyListeners();
      return scan;
    } on ApiException catch (error) {
      if (_captureValidationFailure(error)) {
        return null;
      }
      await _queueStore.enqueueScan(
        mediaFile: file,
        mediaType: mediaType,
        cropType: cropType,
        farmId: farmId,
        fieldId: fieldId,
      );
      _errorMessage = error.toString();
      notifyListeners();
      return null;
    } catch (error) {
      // Queue both images and videos for retry when connectivity returns.
      await _queueStore.enqueueScan(
        mediaFile: file,
        mediaType: mediaType,
        cropType: cropType,
        farmId: farmId,
        fieldId: fieldId,
      );
      await _refreshQueuedCount();
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
      final file = io.File(item.mediaPath);
      if (!file.existsSync()) {
        await _queueStore.removeQueuedScan(item.id);
        continue;
      }

      ScanResult? scan;
      if (item.mediaType == 'video') {
        scan = await submitVideoScan(
          videoFile: file,
          cropType: item.cropType,
          farmId: item.farmId,
          fieldId: item.fieldId,
        );
      } else {
        scan = await submitScan(
          imageFile: file,
          cropType: item.cropType,
          farmId: item.farmId,
          fieldId: item.fieldId,
        );
      }

      if (scan != null) {
        await _queueStore.removeQueuedScan(item.id);
        // For images: result is ready now → show local notification.
        // For videos: backend returns 202 and processes async → FCM push
        // fires later, so we skip the local notification here.
        if (scan.mediaType != 'video') {
          await FcmService.showLocalNotification(
            title: 'Scan Complete ✓',
            body: scan.isHealthy
                ? 'Your crop looks healthy! No disease detected.'
                : '${scan.diseaseNameEn} detected. Tap to view details.',
            scanId: scan.id,
          );
        }
      }
    }
    await _refreshQueuedCount();
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

  Future<ScanResult?> _submitMediaWeb({
    required Uint8List bytes,
    required String filename,
    required String mediaType,
    required String cropType,
    String? farmId,
    String? fieldId,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.multipartBytes(
        '/api/scans',
        auth: true,
        fieldName: 'image',
        bytes: bytes,
        filename: filename,
        timeout: const Duration(seconds: 90),
        fields: {
          'crop_type': cropType,
          ...?(farmId == null ? null : {'farm_id': farmId}),
          ...?(fieldId == null ? null : {'field_id': fieldId}),
          'device_type': 'web',
          'app_version': '1.0.0',
        },
      );
      final scanJson =
          (response['data'] as Map<String, dynamic>)['scan']
              as Map<String, dynamic>;
      // On web the bytes are already in memory — attach them directly so the
      // GradCAM card can display the photo with no additional network trip.
      final scan = ScanResult.fromJson(scanJson).withLocalImageBytes(bytes);
      _upsertScan(scan);
      _errorMessage = null;
      _validationFailure = null;
      notifyListeners();
      return scan;
    } on ApiException catch (error) {
      if (_captureValidationFailure(error)) {
        return null;
      }
      _errorMessage = error.toString();
      notifyListeners();
      return null;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  bool _captureValidationFailure(ApiException error) {
    final code = error.errorCode ?? error.validation?['error_code']?.toString();
    if (error.statusCode != 422 ||
        !{'NOT_A_PLANT', 'UNSUPPORTED_CROP', 'CROP_MISMATCH'}.contains(code)) {
      return false;
    }

    final failure = ScanValidationFailure.fromApiException(error);
    _validationFailure = failure;
    _errorMessage = failure.message;
    if (failure.scan != null) {
      _upsertScan(failure.scan!);
    }
    notifyListeners();
    return true;
  }

  void clearValidationFailure() {
    _validationFailure = null;
    notifyListeners();
  }
}
