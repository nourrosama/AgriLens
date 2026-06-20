import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/forum_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';

/// Unified card used in the community feed for posts, videos, articles and blogs.
/// Stateful so Like/Comment/Share give instant visual feedback.
class FeedCard extends StatefulWidget {
  const FeedCard({super.key, required this.post});
  final ForumPost post;

  @override
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard>
    with SingleTickerProviderStateMixin {
  late bool _liked;
  late int _likesCount;
  late AnimationController _heartCtrl;
  late Animation<double> _heartAnim;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.likedByMe;
    _likesCount = widget.post.likesCount;
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartAnim = Tween<double>(begin: 1, end: 1.35).animate(
      CurvedAnimation(parent: _heartCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    // Optimistic update
    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
    });
    if (_liked) {
      _heartCtrl.forward(from: 0);
    }
    await context.read<ForumProvider>().toggleLike(widget.post.id);
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(post: widget.post),
    );
  }

  Future<void> _deletePost() async {
    final lang = context.read<LanguageProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.isRTL ? 'حذف المنشور؟' : 'Delete Post?'),
        content: Text(
          lang.isRTL
              ? 'لا يمكن التراجع عن هذا الإجراء.'
              : 'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              lang.isRTL ? 'حذف' : 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ok =
          await context.read<ForumProvider>().deletePost(widget.post.id);
      if (mounted && ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.isRTL ? 'تم حذف المنشور' : 'Post deleted'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  void _share() {
    final lang = context.read<LanguageProvider>();
    final text =
        '${widget.post.body}\n\n— ${lang.isRTL ? "مشاركة من منتدى أجري لينس" : "Shared from AgriLens Forum"}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lang.isRTL ? 'تم نسخ المنشور!' : 'Post copied to clipboard!',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final userProvider = context.watch<UserProvider>();
    final currentUserId = userProvider.userId;
    final isOwner = widget.post.authorId == currentUserId;
    final isPremiumPlus =
        userProvider.plan == 'premium' || userProvider.plan == 'professional';
    final isProfessional = userProvider.plan == 'professional';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Author row + type badge + optional menu ──────────────────────
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _Avatar(
                      authorId: widget.post.authorId,
                      authorPhotoUrl: widget.post.authorPhotoUrl,
                      authorName: widget.post.authorName,
                    ),
                    if (isOwner && isPremiumPlus)
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: isProfessional
                                ? const Color(0xFF7B1FA2)
                                : const Color(0xFF1976D2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.star_rounded,
                              color: Colors.white, size: 9),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _shortId(widget.post.authorId),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOwner && isPremiumPlus) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isProfessional
                                    ? const Color(0xFFF3E5F5)
                                    : const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isProfessional
                                      ? const Color(0xFF9C27B0)
                                      : const Color(0xFF1976D2),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                isProfessional
                                    ? (lang.isRTL ? '⭐ محترف' : '⭐ Pro Expert')
                                    : (lang.isRTL ? '⭐ بريميوم' : '⭐ Premium'),
                                style: TextStyle(
                                  color: isProfessional
                                      ? const Color(0xFF6A1B9A)
                                      : const Color(0xFF0D47A1),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _timeAgo(widget.post.createdAt, lang),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _TypeBadge(contentType: widget.post.contentType),
                if (isOwner) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'delete') _deletePost();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(
                              lang.isRTL ? 'حذف المنشور' : 'Delete post',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(height: 10),

            // ── Media preview (if URL present) ───────────────────────────────
            if (widget.post.mediaUrl.isNotEmpty) ...[
              _MediaPreview(post: widget.post),
              const SizedBox(height: 10),
            ],

            // ── Body ─────────────────────────────────────────────────────────
            Text(
              widget.post.body,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),

            // ── Tags ─────────────────────────────────────────────────────────
            if (widget.post.cropTags.isNotEmpty ||
                widget.post.diseaseTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final crop in widget.post.cropTags)
                    _Tag(
                      label: crop,
                      color: AppColors.primary,
                      onTap: () => context.push(
                        '/disease-articles?crop=${Uri.encodeComponent(crop)}',
                      ),
                    ),
                  for (final disease in widget.post.diseaseTags)
                    _Tag(
                      label: disease,
                      color: AppColors.warning,
                      onTap: () => context.push(
                        '/disease-articles?disease=${Uri.encodeComponent(disease)}',
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),

            // ── Action row ───────────────────────────────────────────────────
            Row(
              children: [
                // Like
                _ActionButton(
                  icon: AnimatedBuilder(
                    animation: _heartAnim,
                    builder: (_, __) => Transform.scale(
                      scale: _heartAnim.value,
                      child: Icon(
                        _liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: _liked ? Colors.red : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  label: '$_likesCount',
                  color: _liked ? Colors.red : AppColors.textSecondary,
                  onTap: _toggleLike,
                ),

                const SizedBox(width: 4),

                // Comment
                _ActionButton(
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  label: '${widget.post.commentsCount}',
                  color: AppColors.textSecondary,
                  onTap: _openComments,
                ),

                const Spacer(),

                // Share
                _ActionButton(
                  icon: const Icon(
                    Icons.share_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  label: lang.isRTL ? 'مشاركة' : 'Share',
                  color: AppColors.textSecondary,
                  onTap: _share,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortId(String id) =>
      id.length > 8 ? 'Farmer …${id.substring(id.length - 4)}' : 'Farmer';

  String _timeAgo(DateTime dt, LanguageProvider lang) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return lang.isRTL ? 'الآن' : 'Just now';
    if (diff.inHours < 1) {
      return lang.isRTL
          ? 'منذ ${diff.inMinutes} دقيقة'
          : '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return lang.isRTL
          ? 'منذ ${diff.inHours} ساعة'
          : '${diff.inHours}h ago';
    }
    return lang.isRTL
        ? 'منذ ${diff.inDays} يوم'
        : '${diff.inDays}d ago';
  }
}

// ── Comments bottom sheet ─────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post});
  final ForumPost post;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<ForumComment>? _comments;
  bool _loading = true;
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list =
        await context.read<ForumProvider>().getComments(widget.post.id);
    if (mounted) setState(() { _comments = list; _loading = false; });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final comment =
        await context.read<ForumProvider>().addComment(widget.post.id, text);
    if (mounted && comment != null) {
      _ctrl.clear();
      setState(() {
        _comments = [...?_comments, comment];
        _sending = false;
      });
    } else {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRTL = lang.isRTL;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    isRTL ? 'التعليقات' : 'Comments',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${_comments?.length ?? 0})',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Comments list
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : (_comments == null || _comments!.isEmpty)
                  ? Center(
                      child: Text(
                        isRTL ? 'لا توجد تعليقات بعد' : 'No comments yet',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _comments!.length,
                      itemBuilder: (_, i) {
                        final c = _comments![i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: AppColors.primaryLight,
                                child: Text(
                                  c.authorId.isNotEmpty
                                      ? c.authorId[c.authorId.length - 1]
                                          .toUpperCase()
                                      : 'F',
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    c.body,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // Input
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textDirection:
                          isRTL ? TextDirection.rtl : TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText:
                            isRTL ? 'اكتب تعليقاً…' : 'Write a comment…',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.send_rounded,
                            color: AppColors.primary,
                          ),
                          onPressed: _send,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Media preview ─────────────────────────────────────────────────────────────

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.post});
  final ForumPost post;

  bool get _isVideo {
    final url = post.mediaUrl.toLowerCase();
    return url.endsWith('.mp4') ||
        url.endsWith('.mov') ||
        url.endsWith('.avi') ||
        url.endsWith('.mkv');
  }

  bool get _isPdf {
    return post.mediaUrl.toLowerCase().endsWith('.pdf');
  }

  bool get _isLink {
    return post.mediaUrl.startsWith('http') && !_isVideo && !_isPdf &&
        !post.mediaUrl.toLowerCase().endsWith('.jpg') &&
        !post.mediaUrl.toLowerCase().endsWith('.png') &&
        !post.mediaUrl.toLowerCase().endsWith('.jpeg') &&
        !post.mediaUrl.toLowerCase().endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_outline_rounded,
                  size: 48, color: Colors.white),
              SizedBox(height: 4),
              Text('Video', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (_isPdf) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded,
                color: Color(0xFFD32F2F), size: 24),
            SizedBox(width: 8),
            Text(
              'PDF Document',
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLink) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.link_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                post.mediaUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Image
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        post.mediaUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.authorId, this.authorPhotoUrl = '', this.authorName = ''});
  final String authorId;
  final String authorPhotoUrl;
  final String authorName;

  @override
  Widget build(BuildContext context) {
    final initial = authorName.isNotEmpty
        ? authorName[0].toUpperCase()
        : (authorId.isNotEmpty ? authorId[authorId.length - 1].toUpperCase() : 'F');

    if (authorPhotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.primaryLight,
        backgroundImage: NetworkImage(authorPhotoUrl),
        onBackgroundImageError: (_, _) {},
        child: null,
      );
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primaryLight,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.contentType});
  final String contentType;

  static const _icons = {
    'post': Icons.article_outlined,
    'video': Icons.play_circle_outline_rounded,
    'article': Icons.menu_book_rounded,
    'blog': Icons.edit_note_rounded,
  };

  static const _colors = {
    'post': AppColors.primary,
    'video': Color(0xFF2196F3),
    'article': Color(0xFF9C27B0),
    'blog': Color(0xFFFF5722),
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[contentType] ?? Icons.article_outlined;
    final color = _colors[contentType] ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            contentType,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color, this.onTap});
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          '#$label',
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
