import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class QueuedScanPayload {
  QueuedScanPayload({
    required this.id,
    required this.imagePath,
    required this.cropType,
    this.farmId,
    this.fieldId,
    required this.createdAt,
  });

  final int id;
  final String imagePath;
  final String cropType;
  final String? farmId;
  final String? fieldId;
  final DateTime createdAt;
}

class OfflineQueueStore {
  static const _dbName = 'agrilens_mobile.db';
  static const _table = 'queued_scans';

  Database? _database;

  Future<Database> _db() async {
    if (_database != null) {
      return _database!;
    }
    final directory = await getApplicationDocumentsDirectory();
    final databasePath = path.join(directory.path, _dbName);
    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT NOT NULL,
            crop_type TEXT NOT NULL,
            farm_id TEXT,
            field_id TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  Future<void> enqueueScan({
    required File imageFile,
    required String cropType,
    String? farmId,
    String? fieldId,
  }) async {
    final db = await _db();
    await db.insert(_table, {
      'image_path': imageFile.path,
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
            imagePath: row['image_path'] as String,
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
