import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class QueuedScanPayload {
  QueuedScanPayload({
    required this.id,
    required this.mediaPath,
    required this.mediaType,
    required this.cropType,
    this.farmId,
    this.fieldId,
    required this.createdAt,
  });

  final int id;
  final String mediaPath;
  final String mediaType; // 'image' | 'video'
  final String cropType;
  final String? farmId;
  final String? fieldId;
  final DateTime createdAt;

  // Convenience alias so existing code that reads imagePath still compiles.
  String get imagePath => mediaPath;
}

class OfflineQueueStore {
  static const _dbName = 'agrilens_mobile.db';
  static const _table = 'queued_scans';

  Database? _database;

  Future<Database> _db() async {
    if (_database != null) return _database!;
    final directory = await getApplicationDocumentsDirectory();
    final databasePath = path.join(directory.path, _dbName);
    _database = await openDatabase(
      databasePath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT NOT NULL,
            media_type TEXT NOT NULL DEFAULT 'image',
            crop_type TEXT NOT NULL,
            farm_id TEXT,
            field_id TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE $_table ADD COLUMN media_type TEXT NOT NULL DEFAULT 'image'",
          );
        }
      },
    );
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
    await db.insert(_table, {
      'image_path': mediaFile.path,
      'media_type': mediaType,
      'crop_type': cropType,
      'farm_id': farmId,
      'field_id': fieldId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<QueuedScanPayload>> listQueuedScans() async {
    final db = await _db();
    final rows = await db.query(_table, orderBy: 'created_at ASC');
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
          ),
        )
        .toList();
  }

  Future<void> removeQueuedScan(int id) async {
    final db = await _db();
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
