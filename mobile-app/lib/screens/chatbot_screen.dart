import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/api_client.dart';
import 'package:agrilens/core/chat_history_provider.dart';
import 'package:agrilens/core/chat_history_store.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/plan_gate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _apiClient = ApiClient();

  bool _isTyping = false;
  bool _showSuggestions = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _isAuthenticated = context.read<UserProvider>().isLoggedIn;
      // Load chat history from MongoDB for any authenticated user (mobile or web).
      if (_isAuthenticated) {
        context.read<ChatHistoryProvider>().loadSessionsFromApi(_apiClient);
      }
    });
  }

  // ── Send ────────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final lang = context.read<LanguageProvider>();
    final history = context.read<ChatHistoryProvider>();

    setState(() {
      _isTyping = true;
      _showSuggestions = false;
    });
    _controller.clear();

    try {
      await history.addUserMessage(text);
      _scrollToBottom();

      final endpoint = _isAuthenticated ? '/api/chatbot' : '/api/chatbot-test';
      final body = <String, dynamic>{
        'message': text,
        'lang': lang.isRTL ? 'ar' : 'en',
      };
      // Attach the current MongoDB session_id so the backend appends to the
      // existing session instead of creating a new one each message.
      if (_isAuthenticated && history.currentApiSessionId != null) {
        body['session_id'] = history.currentApiSessionId;
      }

      final response = await _apiClient.post(
        endpoint,
        auth: _isAuthenticated,
        body: body,
      );
      if (!mounted) return;

      final data = response['data'] as Map<String, dynamic>;
      final payload = data['message'] as Map<String, dynamic>;
      await history.addBotMessage(payload['reply']?.toString() ?? '');

      // Persist the returned session_id so future messages stay in the same session.
      if (_isAuthenticated) {
        history.setApiSessionId(data['session_id'] as String?);
      }
    } catch (e) {
      if (!mounted) return;
      await history.addBotMessage(
        'Unable to reach AgriBot right now. Please try again in a moment.',
      );
    } finally {
      if (mounted) setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();
    final history = context.watch<ChatHistoryProvider>();
    final msgs = history.currentMessages;

    // Plan gate — chatbot requires Premium or Professional
    if (user.plan == 'free') {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          ),
          title: Text(
            lang.isRTL ? 'المساعد الزراعي' : 'AI Chatbot',
            style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
          ),
        ),
        body: PlanGateBody(requiredPlan: 'premium', isRTL: lang.isRTL),
      );
    }

    final suggestions = [
      lang.t('chat.question1'),
      lang.t('chat.question2'),
      lang.t('chat.question3'),
      lang.t('chat.question4'),
    ];

    // greeting row is always index 0 in the list; real messages start at 1
    final itemCount =
        1 + msgs.length + (_isTyping ? 1 : 0) + (_showSuggestions && msgs.isEmpty ? 1 : 0);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _HistoryDrawer(
        apiClient: _apiClient,
        onNewChat: () {
          history.startNewChat();
          setState(() {
            _showSuggestions = true;
            _isTyping = false;
          });
          Navigator.of(context).pop();
          _scrollToBottom();
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              color: Colors.white,
              child: Row(
                children: [
                  // Back arrow
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Transform.flip(
                        flipX: lang.isRTL,
                        child: const Icon(
                          Icons.arrow_back,
                          size: 26,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.smart_toy, size: 26, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.t('chat.title'),
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          lang.t('chat.subtitle'),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Hamburger — opens history drawer (right side)
                  GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.menu, size: 26, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            // ── Messages ─────────────────────────────────────────────────────
            Expanded(
              child: history.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(24),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        // index 0: greeting bubble (always)
                        if (index == 0) {
                          return _greetingBubble(lang);
                        }

                        final msgIndex = index - 1;

                        // Real messages
                        if (msgIndex < msgs.length) {
                          return _messageBubble(msgs[msgIndex], lang);
                        }

                        final afterMsgs = index - 1 - msgs.length;

                        // Typing indicator
                        if (_isTyping && afterMsgs == 0) {
                          return _typingIndicator(lang);
                        }

                        // Suggestions (shown only when session has no messages yet)
                        if (_showSuggestions && msgs.isEmpty) {
                          return _suggestions(lang, suggestions);
                        }

                        return const SizedBox.shrink();
                      },
                    ),
            ),

            // ── Input bar ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: lang.t('chat.placeholder'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _controller.text.trim().isNotEmpty
                            ? AppColors.primary
                            : const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Transform.flip(
                        flipX: lang.isRTL,
                        child: Icon(
                          Icons.send,
                          size: 24,
                          color: _controller.text.trim().isNotEmpty
                              ? Colors.white
                              : const Color(0xFF9E9E9E),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────────

  Widget _greetingBubble(LanguageProvider lang) {
    final greeting = '👋 ${lang.t('chat.greeting')}\n\n${lang.t('chat.subtitle')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: lang.isRTL ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: MarkdownBody(
            data: greeting,
            styleSheet: _botMarkdownStyle(),
          ),
        ),
      ),
    );
  }

  Widget _messageBubble(ChatMessage msg, LanguageProvider lang) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: isUser
            ? (lang.isRTL ? Alignment.centerLeft : Alignment.centerRight)
            : (lang.isRTL ? Alignment.centerRight : Alignment.centerLeft),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUser ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isUser ? null : Border.all(color: AppColors.border),
            boxShadow: isUser
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: isUser
              ? Text(
                  msg.text,
                  style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                )
              : MarkdownBody(data: msg.text, styleSheet: _botMarkdownStyle()),
        ),
      ),
    );
  }

  Widget _typingIndicator(LanguageProvider lang) {
    return Align(
      alignment: lang.isRTL ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedDot(delay: 0),
            SizedBox(width: 8),
            _AnimatedDot(delay: 200),
            SizedBox(width: 8),
            _AnimatedDot(delay: 400),
          ],
        ),
      ),
    );
  }

  Widget _suggestions(LanguageProvider lang, List<String> suggestions) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('chat.tryAsking'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ...suggestions.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  _controller.text = entry.value;
                  Future.delayed(const Duration(milliseconds: 100), _send);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        lang.isRTL ? Icons.arrow_back : Icons.arrow_forward,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _botMarkdownStyle() => MarkdownStyleSheet(
        p: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.6),
        strong: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        listBullet: const TextStyle(color: AppColors.primary, fontSize: 15),
        h1: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
        h2: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
        h3: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
        blockquoteDecoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(4),
          border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History Drawer
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryDrawer extends StatelessWidget {
  const _HistoryDrawer({required this.onNewChat, required this.apiClient});

  final VoidCallback onNewChat;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    final history = context.watch<ChatHistoryProvider>();
    final sessions = history.sessions;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Chat History',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // New Chat button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: OutlinedButton.icon(
                onPressed: onNewChat,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Chat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),

            // Session list
            Expanded(
              child: sessions.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No previous chats yet.\nStart a conversation!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) => _SessionTile(
                        session: sessions[index],
                        isActive: history.activeSession?.id == sessions[index].id &&
                            history.activeSession?.apiId == sessions[index].apiId,
                        onTap: () {
                          history.openSession(sessions[index],
                              apiClient: apiClient);
                          Navigator.of(context).pop();
                        },
                        onDelete: () => history.deleteSession(sessions[index],
                            apiClient: apiClient),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  final ChatSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(dt);
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(session.apiId ?? 'local_${session.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete chat?'),
            content: const Text('This conversation will be permanently removed.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.25))
              : null,
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 18,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          title: Text(
            session.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? AppColors.primaryDark : AppColors.textSecondary,
            ),
          ),
          subtitle: Text(
            _dateLabel(session.updatedAt),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated typing dot
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedDot extends StatefulWidget {
  const _AnimatedDot({required this.delay});
  final int delay;

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        transform: Matrix4.translationValues(0, -4 * _controller.value, 0),
        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      ),
    );
  }
}
