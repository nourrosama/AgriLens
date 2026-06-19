import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'local_database.dart';

class QueuedScanPayload {
  QueuedScanPayload({
    required this.id,
    required this.mediaPath,
    required this.mediaType,
    required this.cropType,
    this.farmId,
    this.fieldId,
    required this.createdAt,
    this.syncStatus = 'pending',
    this.retryCount = 0,
    this.lastError,
  });

  final int id;
  final String mediaPath;
  final String mediaType; // 'image' | 'video'
  final String cropType;
  final String? farmId;
  final String? fieldId;
  final DateTime createdAt;
  final String syncStatus;
  final int retryCount;
  final String? lastError;

  // Convenience alias so existing code that reads imagePath still compiles.
  String get imagePath => mediaPath;
}

class OfflineQueueStore {
  static const queuedScansTable = 'queued_scans';
  static const cachedScanResultsTable = 'cached_scan_results';

  Database? _database;

  Future<Database> _db() async {
    if (_database != null) return _database!;
    _database = await LocalDatabase.open();
    return _database!;
  }

  Future<void> enqueueScan({
    required File mediaFile,
    String mediaType = 'image',
    required String cropType,
    String? farmId,
    String? fieldId,
  }) async {
    final db = await _db();
    final stableFile = await _copyMediaToQueueStorage(mediaFile, mediaType);
    await db.insert(queuedScansTable, {
      'image_path': stableFile.path,
      'media_type': mediaType,
      'crop_type': cropType,
      'farm_id': farmId,
      'field_id': fieldId,
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
      'retry_count': 0,
      'last_error': null,
    });
  }

  Future<List<QueuedScanPayload>> listQueuedScans() async {
    final db = await _db();
    final rows = await db.query(queuedScansTable, orderBy: 'created_at ASC');
    return rows
        .map(
          (row) => QueuedScanPayload(
            id: row['id'] as int,
            mediaPath: row['image_path'] as String,
            mediaType: (row['media_type'] as String?) ?? 'image',
            cropType: row['crop_type'] as String,
            farmId: row['farm_id'] as String?,
            fieldId: row['field_id'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
            syncStatus: (row['sync_status'] as String?) ?? 'pending',
            retryCount: (row['retry_count'] as int?) ?? 0,
            lastError: row['last_error'] as String?,
          ),
        )
        .toList();
  }

  Future<void> markQueuedScanSyncing(int id) async {
    final db = await _db();
    await db.update(
      queuedScansTable,
      {'sync_status': 'syncing', 'last_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markQueuedScanFailed(int id, String error) async {
    final db = await _db();
    await db.rawUpdate(
      '''
      UPDATE $queuedScansTable
      SET sync_status = ?, retry_count = retry_count + 1, last_error = ?
      WHERE id = ?
      ''',
      ['failed', error, id],
    );
  }

  Future<void> removeQueuedScan(int id) async {
    final db = await _db();
    await db.delete(queuedScansTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> cacheScanResult(Map<String, dynamic> scanJson) async {
    final scanId = scanJson['id']?.toString() ?? '';
    if (scanId.isEmpty) return;

    final detection = scanJson['detection_result'];
    final detectionJson = detection is Map<String, dynamic>
        ? jsonEncode(detection)
        : null;
    final mediaUrl =
        scanJson['media_url']?.toString() ?? scanJson['image_url']?.toString();
    final createdAt =
        scanJson['created_at']?.toString() ?? DateTime.now().toIso8601String();
    final now = DateTime.now().toIso8601String();
    final db = await _db();

    await db.insert(cachedScanResultsTable, {
      'scan_id': scanId,
      'crop_type': scanJson['crop_type']?.toString() ?? '',
      'media_type': scanJson['media_type']?.toString() ?? 'image',
      'media_url': mediaUrl,
      'detection_result_json': detectionJson,
      'status': scanJson['status']?.toString() ?? 'pending',
      'created_at': createdAt,
      'scan_json': jsonEncode(scanJson),
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> listCachedScanResults() async {
    final db = await _db();
    final rows = await db.query(
      cachedScanResultsTable,
      orderBy: 'created_at DESC',
    );
    return rows
        .map((row) => _decodeScanJson(row['scan_json']?.toString() ?? ''))
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, dynamic>?> getCachedScanResult(String scanId) async {
    final db = await _db();
    final rows = await db.query(
      cachedScanResultsTable,
      where: 'scan_id = ?',
      whereArgs: [scanId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeScanJson(rows.first['scan_json']?.toString() ?? '');
  }

  Map<String, dynamic>? _decodeScanJson(String raw) {
    if (raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<File> _copyMediaToQueueStorage(
    File mediaFile,
    String mediaType,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final queueDirectory = Directory(
      path.join(directory.path, 'offline_scans'),
    );
    if (!queueDirectory.existsSync()) {
      await queueDirectory.create(recursive: true);
    }

    final extension = path.extension(mediaFile.path);
    final safeExtension = extension.isEmpty
        ? (mediaType == 'video' ? '.mp4' : '.jpg')
        : extension;
    final filename =
        '${DateTime.now().microsecondsSinceEpoch}_${path.basenameWithoutExtension(mediaFile.path)}$safeExtension';
    final destination = File(path.join(queueDirectory.path, filename));
    return mediaFile.copy(destination.path);
  }
}
