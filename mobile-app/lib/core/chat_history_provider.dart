import 'package:flutter/foundation.dart';
import 'package:agrilens/core/api_client.dart';
import 'chat_history_store.dart';

/// Auto-generates a session title from the user's first message.
/// Takes up to 45 characters and appends "…" if truncated.
String _deriveTitle(String firstUserMessage) {
  final clean = firstUserMessage.trim().replaceAll('\n', ' ');
  if (clean.length <= 45) return clean;
  return '${clean.substring(0, 45)}…';
}

class ChatHistoryProvider extends ChangeNotifier {
  ChatHistoryProvider() {
    _init();
  }

  final ChatHistoryStore _store = ChatHistoryStore();

  /// True when sqflite is unavailable (web) or fails — falls back to RAM only.
  bool _memoryOnly = false;

  /// Auto-increment counter used for in-memory IDs (never touches the DB).
  int _nextId = 1;

  // All sessions, sorted newest-first
  List<ChatSession> _sessions = [];
  List<ChatSession> get sessions => List.unmodifiable(_sessions);

  // Messages for the active session
  List<ChatMessage> _currentMessages = [];
  List<ChatMessage> get currentMessages => List.unmodifiable(_currentMessages);

  ChatSession? _activeSession;
  ChatSession? get activeSession => _activeSession;

  /// The MongoDB session ID for the currently active chat exchange.
  /// Passed back to the server on subsequent messages so they land in the same session.
  String? _apiSessionId;
  String? get currentApiSessionId => _apiSessionId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    try {
      _sessions = await _store.loadSessions();
    } catch (_) {
      // sqflite not available (web) or DB error — run in memory-only mode.
      _memoryOnly = true;
    }
    notifyListeners();
  }

  // ── API-backed history loading ────────────────────────────────────────────

  /// Load chat sessions from the MongoDB API and merge them into the session list.
  /// Only called for authenticated users. Safe to call multiple times.
  Future<void> loadSessionsFromApi(ApiClient apiClient) async {
    try {
      final response = await apiClient.get('/api/chatbot/sessions', auth: true);
      final data = response['data'] as Map<String, dynamic>?;
      final raw = data?['sessions'] as List<dynamic>? ?? [];
      final apiSessions = raw
          .whereType<Map<String, dynamic>>()
          .map(ChatSession.fromApi)
          .toList();

      // Put API sessions first (they are the source of truth), de-dup by apiId.
      final existingApiIds = apiSessions.map((s) => s.apiId).toSet();
      final localOnly = _sessions
          .where((s) => s.apiId == null || !existingApiIds.contains(s.apiId))
          .toList();

      _sessions = [...apiSessions, ...localOnly];
      _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      notifyListeners();
    } catch (_) {
      // Network error — keep whatever sessions we already have.
    }
  }

  /// Load messages for a session that has an [apiId] from the MongoDB API.
  Future<List<ChatMessage>> _loadMessagesFromApi(
      ApiClient apiClient, String apiSessionId) async {
    try {
      final response = await apiClient.get(
        '/api/chatbot/sessions/$apiSessionId/messages',
        auth: true,
      );
      final data = response['data'] as Map<String, dynamic>?;
      final raw = data?['messages'] as List<dynamic>? ?? [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((m) => ChatMessage.fromApi(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Session management ────────────────────────────────────────────────────

  /// Start a brand-new blank chat (no DB row yet — created on first message).
  void startNewChat() {
    _activeSession = null;
    _currentMessages = [];
    _apiSessionId = null;
    notifyListeners();
  }

  /// Load an existing session and its messages.
  /// Pass [apiClient] to fetch messages from the API when the session has an apiId.
  Future<void> openSession(ChatSession session,
      {ApiClient? apiClient}) async {
    _isLoading = true;
    notifyListeners();

    _activeSession = session;
    _apiSessionId = session.apiId; // resume this session on next message

    if (session.apiId != null && apiClient != null) {
      // Prefer API messages for API-backed sessions
      final apiMessages = await _loadMessagesFromApi(apiClient, session.apiId!);
      if (apiMessages.isNotEmpty) {
        _currentMessages = apiMessages;
        _isLoading = false;
        notifyListeners();
        return;
      }
    }

    if (_memoryOnly) {
      _currentMessages = List<ChatMessage>.from(session.messages);
    } else {
      try {
        _currentMessages = session.id != 0
            ? await _store.loadMessages(session.id)
            : List<ChatMessage>.from(session.messages);
      } catch (_) {
        _memoryOnly = true;
        _currentMessages = List<ChatMessage>.from(session.messages);
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteSession(ChatSession session,
      {ApiClient? apiClient}) async {
    // Delete from API if possible
    if (session.apiId != null && apiClient != null) {
      try {
        await apiClient.delete(
          '/api/chatbot/sessions/${session.apiId}',
          auth: true,
        );
      } catch (_) {
        // ignore — still remove locally
      }
    }

    // Delete from sqflite
    if (!_memoryOnly && session.id != 0) {
      try {
        await _store.deleteSession(session.id);
      } catch (_) {
        _memoryOnly = true;
      }
    }

    _sessions.removeWhere(
        (s) => s.id == session.id && s.apiId == session.apiId);
    if (_activeSession?.apiId == session.apiId &&
        _activeSession?.id == session.id) {
      _activeSession = null;
      _currentMessages = [];
      _apiSessionId = null;
    }
    notifyListeners();
  }

  // ── Messaging ─────────────────────────────────────────────────────────────

  /// Add a user message. Creates the session on first message.
  Future<void> addUserMessage(String text) async {
    if (_activeSession == null) {
      final session = await _createSession(_deriveTitle(text));
      _activeSession = session;
      _sessions.insert(0, session);
    }

    final msg = await _addMessage(
      sessionId: _activeSession!.id,
      text: text,
      isUser: true,
    );
    _currentMessages.add(msg);
    _refreshSessionOrder();
    notifyListeners();
  }

  /// Add the bot reply.
  Future<void> addBotMessage(String text) async {
    if (_activeSession == null) return;
    final msg = await _addMessage(
      sessionId: _activeSession!.id,
      text: text,
      isUser: false,
    );
    _currentMessages.add(msg);
    _refreshSessionOrder();
    notifyListeners();
  }

  /// Called after a successful API response to record the returned session_id.
  /// This ensures subsequent messages continue the same MongoDB session.
  void setApiSessionId(String? id) {
    if (_apiSessionId == id) return;
    _apiSessionId = id;

    // Annotate the active session with its apiId so the drawer can use it later.
    if (id != null && _activeSession != null && _activeSession!.apiId != id) {
      final updated = _activeSession!.copyWith(apiId: id);
      _activeSession = updated;
      final idx = _sessions.indexWhere((s) => s.id == updated.id);
      if (idx != -1) {
        _sessions[idx] = updated;
        notifyListeners();
      }
    }
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  Future<ChatSession> _createSession(String title) async {
    if (_memoryOnly) return _memorySession(title);
    try {
      return await _store.createSession(title);
    } catch (_) {
      _memoryOnly = true;
      return _memorySession(title);
    }
  }

  Future<ChatMessage> _addMessage({
    required int sessionId,
    required String text,
    required bool isUser,
  }) async {
    if (_memoryOnly) return _memoryMessage(sessionId, text, isUser);
    try {
      return await _store.addMessage(
        sessionId: sessionId,
        text: text,
        isUser: isUser,
      );
    } catch (_) {
      _memoryOnly = true;
      return _memoryMessage(sessionId, text, isUser);
    }
  }

  ChatSession _memorySession(String title) {
    final now = DateTime.now();
    return ChatSession(
      id: _nextId++,
      title: title,
      createdAt: now,
      updatedAt: now,
    );
  }

  ChatMessage _memoryMessage(int sessionId, String text, bool isUser) {
    return ChatMessage(
      id: _nextId++,
      sessionId: sessionId,
      text: text,
      isUser: isUser,
      createdAt: DateTime.now(),
    );
  }

  /// Re-sort sessions so the most-recently-updated appears first.
  void _refreshSessionOrder() {
    _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}
