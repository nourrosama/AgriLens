import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/api_client.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _apiClient = ApiClient();
  final List<_Msg> _messages = [];
  bool _isTyping = false;
  bool _showSuggestions = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lang = context.read<LanguageProvider>();
      final greeting = '👋 ${lang.t('chat.greeting')}\n\n${lang.t('chat.subtitle')}';
      setState(() {
        _messages.add(_Msg(greeting, false));
        _showSuggestions = true;
      });
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final lang = context.read<LanguageProvider>();

    setState(() {
      _messages.add(_Msg(text, true));
      _isTyping = true;
      _showSuggestions = false;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final endpoint = kIsWeb ? '/api/chatbot-test' : '/api/chatbot';
      final requiresAuth = !kIsWeb;

      final response = await _apiClient.post(
        endpoint,
        auth: requiresAuth,
        body: {
          'message': text,
          'lang': lang.isRTL ? 'ar' : 'en',
        },
      );
      final payload =
          (response['data'] as Map<String, dynamic>)['message']
              as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(payload['reply']?.toString() ?? '', false));
        _isTyping = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _Msg(
            'Unable to reach AgriBot right now. Please try again in a moment. Error: $e',
            false,
          ),
        );
        _isTyping = false;
      });
    }
    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final suggestions = [
      lang.t('chat.question1'),
      lang.t('chat.question2'),
      lang.t('chat.question3'),
      lang.t('chat.question4'),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Transform.flip(
                        flipX: lang.isRTL,
                        child: const Icon(
                          Icons.arrow_back,
                          size: 28,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy,
                      size: 28,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.t('chat.title'),
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        lang.t('chat.subtitle'),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                itemCount:
                    _messages.length +
                    (_isTyping ? 1 : 0) +
                    (_showSuggestions && _messages.length == 1 ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    return _messageBubble(_messages[index], lang);
                  }
                  if (_isTyping && index == _messages.length) {
                    return _typingIndicator(lang);
                  }
                  if (_showSuggestions && _messages.length == 1) {
                    return _suggestions(lang, suggestions);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
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
                          borderSide: const BorderSide(
                            color: AppColors.border,
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
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

  Widget _messageBubble(_Msg msg, LanguageProvider lang) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: isUser
            ? (lang.isRTL ? Alignment.centerLeft : Alignment.centerRight)
            : (lang.isRTL ? Alignment.centerRight : Alignment.centerLeft),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
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
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.5,
        ),
      )
    : MarkdownBody(
        data: msg.text,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.6,
          ),
          strong: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          listBullet: const TextStyle(
            color: AppColors.primary,
            fontSize: 15,
          ),
          h3: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
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
            (entry) {
              final index = entry.key;
              final question = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    _controller.text = question;
                    Future.delayed(const Duration(milliseconds: 100), _send);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
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
                              '${index + 1}',
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
                            question,
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
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _Msg {
  _Msg(this.text, this.isUser);
  final String text;
  final bool isUser;
}

class _AnimatedDot extends StatefulWidget {
  const _AnimatedDot({required this.delay});
  final int delay;

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
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
      builder: (context, child) => Container(
        width: 8,
        height: 8,
        transform: Matrix4.translationValues(0, -4 * _controller.value, 0),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}