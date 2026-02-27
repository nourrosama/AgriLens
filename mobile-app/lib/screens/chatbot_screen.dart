import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Msg> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Add initial greeting after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = context.read<LanguageProvider>();
      setState(() => _messages.add(_Msg(lang.t('chat.greeting'), false)));
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Msg(text, true));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();
    final lang = context.read<LanguageProvider>();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(_getResponse(text, lang), false));
        _isTyping = false;
      });
      _scrollToBottom();
    });
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

  String _getResponse(String msg, LanguageProvider lang) {
    final m = msg.toLowerCase();
    if (m.contains('tomato') || m.contains('طماطم')) {
      return lang.isRTL
          ? 'الطماطم عادة تصاب باللفحة المبكرة، اللفحة المتأخرة، وبقع الأوراق. الكشف المبكر أساسي!'
          : 'Tomatoes are commonly affected by Early Blight, Late Blight, and Leaf Spot. Early detection is key!';
    }
    if (m.contains('blight') || m.contains('لفحة')) {
      return lang.isRTL
          ? 'يمكن الوقاية من اللفحة عن طريق:\n• تدوير المحاصيل\n• تباعد مناسب\n• تجنب الري العلوي\n• استخدام المبيدات الفطرية وقائياً'
          : 'Blight can be prevented by:\n• Crop rotation\n• Proper spacing\n• Avoiding overhead watering\n• Applying fungicides preventively';
    }
    if (m.contains('fertilizer') || m.contains('سماد')) {
      return lang.isRTL
          ? 'للقمح، استخدم سماد NPK. ضع النيتروجين على دفعات: 50٪ عند الزراعة، 25٪ عند التفريع، و25٪ عند التزهير.'
          : 'For wheat, use NPK fertilizer. Apply nitrogen in split doses: 50% at sowing, 25% at tillering, 25% at flowering.';
    }
    if (m.contains('water') || m.contains('ري') || m.contains('ماء')) {
      return lang.isRTL
          ? 'اروي المحاصيل في الصباح الباكر أو المساء. معظم المحاصيل تحتاج 2-5 سم من الماء أسبوعياً.'
          : 'Water crops early morning or late evening. Most crops need 1-2 inches of water per week.';
    }
    return lang.isRTL
        ? 'أنا أجري بوت، مساعدك الزراعي! يمكنني مساعدتك في:\n• تحديد الأمراض\n• إدارة الآفات\n• توصيات الأسمدة\n• جداول الري'
        : 'I\'m AgriBot! I can help you with:\n• Disease identification\n• Pest management\n• Fertilizer recommendations\n• Watering schedules';
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
        child: Column(children: [
          // Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Transform.flip(
                    flipX: lang.isRTL,
                    child: const Icon(Icons.arrow_back, size: 28, color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                child: const Icon(Icons.smart_toy, size: 28, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lang.t('chat.title'), style: const TextStyle(color: AppColors.primaryDark, fontSize: 18, fontWeight: FontWeight.w600)),
                Text(lang.t('chat.subtitle'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ]),
            ]),
          ),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              itemCount: _messages.length + (_isTyping ? 1 : 0) + (_messages.length == 1 ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i < _messages.length) return _messageBubble(_messages[i], lang);
                if (_isTyping && i == _messages.length) return _typingIndicator(lang);
                return _suggestedQuestions(lang, suggestions);
              },
            ),
          ),
          // Input
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: lang.t('chat.placeholder'),
                    hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 2)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border, width: 2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _controller.text.trim().isNotEmpty ? AppColors.primary : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Transform.flip(
                    flipX: lang.isRTL,
                    child: Icon(Icons.send, size: 24,
                        color: _controller.text.trim().isNotEmpty ? Colors.white : const Color(0xFF9E9E9E)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
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
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUser ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isUser ? null : Border.all(color: AppColors.border),
          ),
          child: Text(msg.text,
              style: TextStyle(
                color: isUser ? Colors.white : AppColors.textSecondary,
                fontSize: 16, height: 1.5,
              )),
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (int i = 0; i < 3; i++) ...[
            _AnimatedDot(delay: i * 200),
            if (i < 2) const SizedBox(width: 8),
          ],
        ]),
      ),
    );
  }

  Widget _suggestedQuestions(LanguageProvider lang, List<String> suggestions) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(children: [
        Text(lang.t('chat.tryAsking'),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 12),
        ...suggestions.map((q) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => setState(() => _controller.text = q),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(q, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            ),
          ),
        )),
      ]),
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
  final String text;
  final bool isUser;
  _Msg(this.text, this.isUser);
}

class _AnimatedDot extends StatefulWidget {
  final int delay;
  const _AnimatedDot({required this.delay});
  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Container(
        width: 8, height: 8,
        transform: Matrix4.translationValues(0, -4 * _ctrl.value, 0),
        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      ),
    );
  }
}
