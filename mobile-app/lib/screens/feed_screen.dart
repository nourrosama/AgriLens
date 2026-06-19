import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/forum_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/widgets/bottom_nav.dart';
import 'package:agrilens/widgets/feed_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _scrollController = ScrollController();
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index != _currentTab) {
        setState(() => _currentTab = _tabs.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ForumProvider>().loadFeed(refresh: true);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Defer the load so it doesn't notifyListeners() mid-frame,
      // which would produce "Cannot hit test" errors on web.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<ForumProvider>().loadFeed();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRTL = lang.isRTL;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isRTL ? 'منتدى المجتمع الزراعي' : 'Farmer Community',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: isRTL ? 'الكل' : 'All'),
            Tab(text: isRTL ? 'أسئلة' : 'Q&A'),
            Tab(text: isRTL ? 'الأكثر تداولاً' : 'Trending'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FeedTab(scrollController: _scrollController),
          const _QaTab(),
          const _TrendingTab(),
        ],
      ),
      floatingActionButton: _currentTab == 2
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              // No tooltip: on Flutter web the FAB tooltip creates an Overlay
              // entry that reads the FAB's render-box position before layout
              // completes, triggering a cascade of "Assertion failed /
              // proxy_box performLayout" errors that block tap delivery.
              onPressed: () {
                final tab = _currentTab;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (tab == 1) {
                    context.push('/ask-question');
                  } else {
                    context.push('/create-post');
                  }
                });
              },
              child: Icon(
                _currentTab == 1
                    ? Icons.help_outline_rounded
                    : Icons.edit_rounded,
              ),
            ),
      bottomNavigationBar: const BottomNav(active: 'forum'),
    );
  }
}

// ── All-posts tab ─────────────────────────────────────────────────────────────

class _FeedTab extends StatelessWidget {
  const _FeedTab({required this.scrollController});
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final forum = context.watch<ForumProvider>();

    // Always keep the same top-level widget type (RefreshIndicator >
    // ListView.builder) so Flutter never swaps out the render object during
    // a frame.  Switching from CircularProgressIndicator to ListView.builder
    // mid-frame creates unlaid-out render objects that break hit testing on
    // Flutter web.  Instead, the loading / empty states are rendered as list
    // items so the ListView render object is created once and reused.
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => forum.loadFeed(refresh: true),
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: _itemCount(forum),
        itemBuilder: (context, index) {
          // Initial loading state
          if (forum.feedLoading && forum.feed.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          // Empty state
          if (forum.feed.isEmpty) {
            return _EmptyFeed();
          }
          // "Load more" spinner at the end
          if (index == forum.feed.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          return FeedCard(post: forum.feed[index]);
        },
      ),
    );
  }

  int _itemCount(ForumProvider forum) {
    if (forum.feedLoading && forum.feed.isEmpty) return 1;
    if (forum.feed.isEmpty) return 1;
    return forum.feed.length + (forum.feedHasMore ? 1 : 0);
  }

  void _showPostDetail(BuildContext context, ForumPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostDetailSheet(post: post),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRTL = lang.isRTL;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_rounded, size: 64, color: AppColors.border),
          const SizedBox(height: 16),
          Text(
            isRTL ? 'لا توجد منشورات بعد' : 'No posts yet',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isRTL ? 'كن أول من يشارك تجربته!' : 'Be the first to share!',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Q&A tab ───────────────────────────────────────────────────────────────────

class _QaTab extends StatefulWidget {
  const _QaTab();

  @override
  State<_QaTab> createState() => _QaTabState();
}

class _QaTabState extends State<_QaTab> {
  List<ForumQuestion>? _questions;
  bool _loading = true;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final questions = await context.read<ForumProvider>().getQuestions(
      filter: _filter,
    );
    if (mounted) {
      setState(() {
        _questions = questions;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRTL = lang.isRTL;
    final questions = _questions ?? [];

    // Always keep RefreshIndicator > ListView as the top-level widget so
    // Flutter never swaps the render object mid-frame (avoids unlaid-out
    // render boxes that break mouse-tracker hit testing on Flutter web).
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        setState(() => _loading = true);
        await _load();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: (_loading || questions.isEmpty) ? 2 : questions.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return _QuestionFilters(
              selected: _filter,
              isRTL: isRTL,
              onSelected: (value) async {
                setState(() {
                  _filter = value;
                  _loading = true;
                });
                await _load();
              },
            );
          }
          if (_loading) {
            return const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          if (questions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Text(
                  isRTL ? 'لا توجد أسئلة بعد' : 'No questions yet',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          final q = questions[i - 1];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: q.isResolved
                    ? AppColors.primaryLight
                    : AppColors.warningLight,
                child: Icon(
                  q.isResolved
                      ? Icons.check_circle_rounded
                      : Icons.help_outline_rounded,
                  color: q.isResolved ? AppColors.primary : AppColors.warning,
                  size: 20,
                ),
              ),
              title: Text(
                q.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                '${q.answerCount} ${isRTL ? "إجابة" : "answers"}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
              onTap: () => context.push('/question/${q.id}'),
            ),
          );
        },
      ),
    );
  }
}

// ── Trending tab ──────────────────────────────────────────────────────────────

class _QuestionFilters extends StatelessWidget {
  const _QuestionFilters({
    required this.selected,
    required this.isRTL,
    required this.onSelected,
  });

  final String selected;
  final bool isRTL;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final filters = <({String value, String labelEn, String labelAr})>[
      (value: '', labelEn: 'All', labelAr: 'الكل'),
      (value: 'my_questions', labelEn: 'My questions', labelAr: 'أسئلتي'),
      (
        value: 'answered_by_me',
        labelEn: 'Answered by me',
        labelAr: 'إجاباتي',
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          for (final filter in filters) ...[
            ChoiceChip(
              label: Text(isRTL ? filter.labelAr : filter.labelEn),
              selected: selected == filter.value,
              selectedColor: AppColors.primaryLight,
              labelStyle: TextStyle(
                color: selected == filter.value
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
                fontWeight: selected == filter.value
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
              onSelected: (_) => onSelected(filter.value),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _TrendingTab extends StatefulWidget {
  const _TrendingTab();

  @override
  State<_TrendingTab> createState() => _TrendingTabState();
}

class _TrendingTabState extends State<_TrendingTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await context.read<ForumProvider>().getTrending();
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRTL = lang.isRTL;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final topCrops =
        (_data?['top_crops'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    final topDiseases =
        (_data?['top_diseases'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    final trendingPosts =
        (_data?['trending_posts'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        setState(() => _loading = true);
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(
            icon: Icons.eco_rounded,
            title: isRTL ? 'أكثر المحاصيل فحصاً' : 'Most Scanned Crops',
          ),
          const SizedBox(height: 8),
          if (topCrops.isEmpty)
            _emptyHint(isRTL ? 'لا توجد بيانات' : 'No data yet')
          else
            ...topCrops.map(
              (c) => _TrendingRow(
                label: c['crop']?.toString() ?? '',
                count: (c['scan_count'] as num?)?.toInt() ?? 0,
                suffix: isRTL ? 'فحص' : 'scans',
                color: AppColors.primary,
              ),
            ),

          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.warning_amber_rounded,
            title: isRTL ? 'أكثر الأمراض انتشاراً' : 'Most Detected Diseases',
          ),
          const SizedBox(height: 8),
          if (topDiseases.isEmpty)
            _emptyHint(isRTL ? 'لا توجد بيانات' : 'No data yet')
          else
            ...topDiseases.map(
              (d) => _TrendingRow(
                label: d['disease']?.toString() ?? '',
                count: (d['count'] as num?)?.toInt() ?? 0,
                suffix: isRTL ? 'حالة' : 'cases',
                color: AppColors.warning,
              ),
            ),

          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.local_fire_department_rounded,
            title: isRTL ? 'المنشورات الأكثر تفاعلاً' : 'Hot Posts This Week',
          ),
          const SizedBox(height: 8),
          if (trendingPosts.isEmpty)
            _emptyHint(isRTL ? 'لا توجد منشورات بعد' : 'No posts this week')
          else
            ...trendingPosts.map(
              (p) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['body']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            size: 14,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${p['likes_count'] ?? 0}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${p['comments_count'] ?? 0}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _emptyHint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.primaryDark,
          ),
        ),
      ],
    );
  }
}

class _TrendingRow extends StatelessWidget {
  const _TrendingRow({
    required this.label,
    required this.count,
    required this.suffix,
    required this.color,
  });
  final String label;
  final int count;
  final String suffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '$count $suffix',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Post detail bottom sheet ──────────────────────────────────────────────────

class _PostDetailSheet extends StatefulWidget {
  const _PostDetailSheet({required this.post});
  final ForumPost post;

  @override
  State<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<_PostDetailSheet> {
  List<ForumComment>? _comments;
  bool _loading = true;
  final _commentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final comments =
        await context.read<ForumProvider>().getComments(widget.post.id);
    if (mounted) setState(() { _comments = comments; _loading = false; });
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final comment = await context
        .read<ForumProvider>()
        .addComment(widget.post.id, text);
    if (mounted && comment != null) {
      _commentCtrl.clear();
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
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
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
            // Post body
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.post.body,
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
            ),
            const Divider(height: 24),
            // Comments
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _comments?.length ?? 0,
                      itemBuilder: (_, i) {
                        final c = _comments![i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primaryLight,
                                child: Text(
                                  c.authorId.isNotEmpty
                                      ? c.authorId[c.authorId.length - 1]
                                          .toUpperCase()
                                      : 'F',
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
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
            // Comment input
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
                      controller: _commentCtrl,
                      textDirection:
                          isRTL ? TextDirection.rtl : TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: isRTL ? 'اكتب تعليقاً...' : 'Add a comment…',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
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
                          onPressed: _sendComment,
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
