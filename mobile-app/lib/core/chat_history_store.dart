import 'package:sqflite/sqflite.dart';

import 'local_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.text,
    required this.isUser,
    required this.createdAt,
    this.apiId,
  });

  final int id;
  final int sessionId;
  final String? apiId; // MongoDB _id (null for local-only messages)
  final String text;
  final bool isUser;
  final DateTime createdAt;

  factory ChatMessage.fromRow(Map<String, dynamic> row) => ChatMessage(
    id: row['id'] as int,
    sessionId: row['session_id'] as int,
    text: row['text'] as String,
    isUser: (row['is_user'] as int) == 1,
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  factory ChatMessage.fromApi(
    Map<String, dynamic> json, {
    int localSessionId = 0,
  }) => ChatMessage(
    id: 0,
    sessionId: localSessionId,
    apiId: json['id'] as String?,
    text: json['text'] as String? ?? '',
    isUser: json['is_user'] as bool? ?? false,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
  );
}

class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.apiId,
    this.messages = const [],
  });

  final int id;
  final String? apiId; // MongoDB _id (null for local-only sessions)
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  ChatSession copyWith({
    String? title,
    String? apiId,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) => ChatSession(
    id: id,
    apiId: apiId ?? this.apiId,
    title: title ?? this.title,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    messages: messages ?? this.messages,
  );

  factory ChatSession.fromRow(Map<String, dynamic> row) => ChatSession(
    id: row['id'] as int,
    title: row['title'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );

  factory ChatSession.fromApi(Map<String, dynamic> json) => ChatSession(
    id: 0,
    apiId: json['id'] as String?,
    title: json['title'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updated_at'] as String? ?? '') ??
        DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Store
// ─────────────────────────────────────────────────────────────────────────────

class ChatHistoryStore {
  static const _sessions = 'chat_sessions';
  static const _messages = 'chat_messages';

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    _db = await LocalDatabase.open();
    return _db!;
  }

  Future<List<ChatSession>> loadSessions() async {
    final db = await _open();
    final rows = await db.query(_sessions, orderBy: 'updated_at DESC');
    return rows.map(ChatSession.fromRow).toList();
  }

  Future<ChatSession> createSession(String title) async {
    final db = await _open();
    final now = DateTime.now().toIso8601String();
    final id = await db.insert(_sessions, {
      'title': title,
      'created_at': now,
      'updated_at': now,
    });
    return ChatSession(
      id: id,
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> renameSession(int id, String title) async {
    final db = await _open();
    await db.update(
      _sessions,
      {'title': title, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> touchSession(int id) async {
    final db = await _open();
    await db.update(
      _sessions,
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSession(int id) async {
    final db = await _open();
    // Messages are deleted via ON DELETE CASCADE
    await db.delete(_sessions, where: 'id = ?', whereArgs: [id]);
  }

  // ── Messages ───────────────────────────────────────────────────────────────

  Future<List<ChatMessage>> loadMessages(int sessionId) async {
    final db = await _open();
    final rows = await db.query(
      _messages,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ChatMessage.fromRow).toList();
  }

  Future<ChatMessage> addMessage({
    required int sessionId,
    required String text,
    required bool isUser,
  }) async {
    final db = await _open();
    final now = DateTime.now().toIso8601String();
    final id = await db.insert(_messages, {
      'session_id': sessionId,
      'text': text,
      'is_user': isUser ? 1 : 0,
      'created_at': now,
    });
    await touchSession(sessionId);
    return ChatMessage(
      id: id,
      sessionId: sessionId,
      text: text,
      isUser: isUser,
      createdAt: DateTime.now(),
    );
  }
}
