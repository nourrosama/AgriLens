import 'package:flutter/material.dart';

import 'api_client.dart';

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.sender,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String sender; // 'user' | 'admin'
  final String senderName;
  final String text;
  final DateTime createdAt;

  bool get isUser => sender == 'user';

  factory SupportMessage.fromJson(Map<String, dynamic> j) {
    String ts = j['created_at']?.toString() ?? '';
    if (ts.isNotEmpty &&
        !ts.endsWith('Z') &&
        !RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(ts)) {
      ts += 'Z';
    }
    return SupportMessage(
      id: j['id']?.toString() ?? '',
      sender: j['sender']?.toString() ?? 'user',
      senderName: j['sender_name']?.toString() ?? '',
      text: j['text']?.toString() ?? '',
      createdAt: DateTime.tryParse(ts)?.toLocal() ?? DateTime.now(),
    );
  }
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  final String subject;
  final String status; // 'open' | 'replied' | 'closed'
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SupportMessage> messages;

  bool get isClosed => status == 'closed';
  bool get hasNewReply => status == 'replied';

  factory SupportTicket.fromJson(Map<String, dynamic> j) {
    String _ts(String? raw) {
      if (raw == null || raw.isEmpty) return '';
      if (!raw.endsWith('Z') && !RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw)) {
        return '${raw}Z';
      }
      return raw;
    }

    final msgs = (j['messages'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(SupportMessage.fromJson)
        .toList();

    return SupportTicket(
      id: j['id']?.toString() ?? '',
      subject: j['subject']?.toString() ?? '',
      status: j['status']?.toString() ?? 'open',
      createdAt: DateTime.tryParse(_ts(j['created_at']?.toString()))?.toLocal() ?? DateTime.now(),
      updatedAt: DateTime.tryParse(_ts(j['updated_at']?.toString()))?.toLocal() ?? DateTime.now(),
      messages: msgs,
    );
  }
}

class SupportProvider extends ChangeNotifier {
  SupportProvider({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  List<SupportTicket> _tickets = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  String _currentUserId = '';

  List<SupportTicket> get tickets => List.unmodifiable(_tickets);

  /// The most recent open / replied ticket (null if none).
  SupportTicket? get activeTicket {
    final open = _tickets.where((t) => !t.isClosed).toList();
    if (open.isEmpty) return null;
    open.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return open.first;
  }

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;

  // ── lifecycle ────────────────────────────────────────────────────────────────

  void onUserChanged(String userId) {
    if (userId == _currentUserId) return;
    _currentUserId = userId;
    if (userId.isEmpty) {
      _tickets = [];
      notifyListeners();
    } else {
      loadTickets();
    }
  }

  // ── API calls ────────────────────────────────────────────────────────────────

  Future<void> loadTickets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _apiClient.get('/api/support/tickets', auth: true);
      final list = (res['data']?['tickets'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(SupportTicket.fromJson)
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _tickets = list;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submit a brand-new ticket (first message from user).
  Future<String?> submitTicket({
    required String subject,
    required String message,
  }) async {
    _isSending = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _apiClient.post(
        '/api/support/tickets',
        auth: true,
        body: {'subject': subject, 'message': message},
      );
      final ticket = SupportTicket.fromJson(
        res['data']['ticket'] as Map<String, dynamic>,
      );
      _tickets.insert(0, ticket);
      return null; // success
    } catch (e) {
      _error = e.toString();
      return _error;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// User sends a follow-up message to an existing ticket.
  Future<String?> sendFollowUp({
    required String ticketId,
    required String message,
  }) async {
    _isSending = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _apiClient.post(
        '/api/support/tickets/$ticketId/messages',
        auth: true,
        body: {'message': message},
      );
      final updated = SupportTicket.fromJson(
        res['data']['ticket'] as Map<String, dynamic>,
      );
      final idx = _tickets.indexWhere((t) => t.id == ticketId);
      if (idx >= 0) {
        _tickets[idx] = updated;
      }
      return null;
    } catch (e) {
      _error = e.toString();
      return _error;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }
}
