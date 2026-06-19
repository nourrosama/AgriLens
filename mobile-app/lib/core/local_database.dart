import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static const dbName = 'agrilens_mobile.db';
  static const version = 3;

  static Database? _database;

  static Future<Database> open() async {
    if (_database != null) return _database!;
    final directory = await getApplicationDocumentsDirectory();
    final databasePath = path.join(directory.path, dbName);
    _database = await openDatabase(
      databasePath,
      version: version,
      onCreate: (db, _) async => _createSchema(db),
      onUpgrade: (db, oldVersion, _) async => _migrate(db, oldVersion),
    );
    return _database!;
  }

  static Future<void> _createSchema(Database db) async {
    await _createQueuedScans(db);
    await _createCachedScanResults(db);
    await _createChatTables(db);
  }

  static Future<void> _migrate(Database db, int oldVersion) async {
    await _createQueuedScans(db);
    await _createCachedScanResults(db);
    await _createChatTables(db);

    if (oldVersion < 2) {
      await _addColumnIfMissing(
        db,
        'queued_scans',
        'media_type',
        "TEXT NOT NULL DEFAULT 'image'",
      );
    }
    if (oldVersion < 3) {
      await _addColumnIfMissing(
        db,
        'queued_scans',
        'sync_status',
        "TEXT NOT NULL DEFAULT 'pending'",
      );
      await _addColumnIfMissing(
        db,
        'queued_scans',
        'retry_count',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'queued_scans', 'last_error', 'TEXT');
    }
  }

  static Future<void> _createQueuedScans(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS queued_scans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        media_type TEXT NOT NULL DEFAULT 'image',
        crop_type TEXT NOT NULL,
        farm_id TEXT,
        field_id TEXT,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_queued_scans_status_created '
      'ON queued_scans(sync_status, created_at)',
    );
  }

  static Future<void> _createCachedScanResults(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_scan_results (
        scan_id TEXT PRIMARY KEY,
        crop_type TEXT NOT NULL,
        media_type TEXT NOT NULL,
        media_url TEXT,
        detection_result_json TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        scan_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cached_scan_results_created '
      'ON cached_scan_results(created_at DESC)',
    );
  }

  static Future<void> _createChatTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
        text TEXT NOT NULL,
        is_user INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_msg_session ON chat_messages(session_id)',
    );
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }
}
