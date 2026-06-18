import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/support_provider.dart';
import 'package:agrilens/core/theme.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  // ── Compose form (no active ticket) ───────────────────────────────────────
  final _subjectCtrl  = TextEditingController();
  final _composeCtrl  = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  // ── Chat follow-up ─────────────────────────────────────────────────────────
  final _replyCtrl    = TextEditingController();
  final _scrollCtrl   = ScrollController();

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportProvider>().loadTickets();
    });
    // Poll every 30 s for new admin replies.
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) context.read<SupportProvider>().loadTickets();
    });
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _composeCtrl.dispose();
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Submit new ticket ──────────────────────────────────────────────────────
  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<SupportProvider>();
    final err = await provider.submitTicket(
      subject: _subjectCtrl.text.trim(),
      message: _composeCtrl.text.trim(),
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      _subjectCtrl.clear();
      _composeCtrl.clear();
      _scrollToBottom();
    }
  }

  // ── Follow-up reply ────────────────────────────────────────────────────────
  Future<void> _sendReply(String ticketId) async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    _replyCtrl.clear();
    final provider = context.read<SupportProvider>();
    final err = await provider.sendFollowUp(ticketId: ticketId, message: text);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } else {
      _scrollToBottom();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(lang),
            Expanded(
              child: Consumer<SupportProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading && provider.tickets.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final ticket = provider.activeTicket;
                  if (ticket == null) {
                    return _buildComposeView(lang, provider);
                  }
                  return _buildChatView(lang, provider, ticket);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header bar ─────────────────────────────────────────────────────────────
  Widget _buildHeader(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Transform.flip(
                flipX: lang.isRTL,
                child: const Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.t('support.title'),
                style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827),
                ),
              ),
              Text(
                lang.t('support.subtitle'),
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Compose view (no active ticket) ───────────────────────────────────────
  Widget _buildComposeView(LanguageProvider lang, SupportProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang.isRTL
                          ? 'أرسل رسالتك وسنرد عليك في التطبيق.'
                          : 'Send us a message and we\'ll reply right here in the app.',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _label(lang.t('support.subject')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _subjectCtrl,
              decoration: _inputDec(),
              validator: (v) => (v == null || v.trim().isEmpty) ? ' ' : null,
            ),
            const SizedBox(height: 16),
            _label(lang.t('support.message')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _composeCtrl,
              maxLines: 5,
              decoration: _inputDec(hint: lang.t('support.messagePlaceholder')),
              validator: (v) => (v == null || v.trim().isEmpty) ? ' ' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: provider.isSending ? null : _submitTicket,
                icon: provider.isSending
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
                label: Text(lang.t('support.submit')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chat view (active ticket exists) ──────────────────────────────────────
  Widget _buildChatView(
    LanguageProvider lang,
    SupportProvider provider,
    SupportTicket ticket,
  ) {
    final messages = ticket.messages;

    return Column(
      children: [
        // Status bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ticket.subject,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(ticket.status),
            ],
          ),
        ),
        const Divider(height: 1),

        // Message thread
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.loadTickets,
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: messages.length,
              itemBuilder: (context, i) => _buildBubble(messages[i], lang),
            ),
          ),
        ),

        // Reply input (only when ticket is not closed)
        if (!ticket.isClosed)
          _buildReplyBar(ticket.id, provider)
        else
          Container(
            padding: const EdgeInsets.all(14),
            color: Colors.white,
            child: Text(
              lang.isRTL ? 'هذه المحادثة مغلقة.' : 'This conversation is closed.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _buildBubble(SupportMessage msg, LanguageProvider lang) {
    final isUser = msg.isUser;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
          bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
        ),
        border: isUser ? null : Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                msg.senderName,
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary,
                ),
              ),
            ),
          Text(
            msg.text,
            style: TextStyle(
              fontSize: 14,
              color: isUser ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(msg.createdAt, lang.isRTL),
            style: TextStyle(
              fontSize: 10,
              color: isUser ? Colors.white70 : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(Icons.support_agent, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
          ],
          bubble,
        ],
      ),
    );
  }

  Widget _buildReplyBar(String ticketId, SupportProvider provider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyCtrl,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type a message…',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: provider.isSending ? null : () => _sendReply(ticketId),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: provider.isSending ? Colors.grey : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: provider.isSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'replied':
        bg = const Color(0xFFE3F2FD); fg = const Color(0xFF1565C0);
        break;
      case 'closed':
        bg = const Color(0xFFF5F5F5); fg = const Color(0xFF757575);
        break;
      default:
        bg = const Color(0xFFE8F5E9); fg = AppColors.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  String _formatTime(DateTime dt, bool arabic) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return arabic ? 'الآن' : 'Just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return arabic ? 'منذ $m دقيقة' : '${m}m ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return arabic ? 'منذ $h ساعة' : '${h}h ago';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF374151), fontSize: 15, fontWeight: FontWeight.w500,
        ),
      );

  InputDecoration _inputDec({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
      );
}
