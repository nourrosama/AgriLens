import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:agrilens/core/disease_articles_service.dart';
import 'package:agrilens/core/forum_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/widgets/feed_card.dart';

/// Shows community articles and posts related to a specific disease.
/// Route: /disease-articles?disease=<name>&crop=<optional>
class DiseaseArticlesScreen extends StatefulWidget {
  final String disease;
  final String crop;

  const DiseaseArticlesScreen({
    super.key,
    required this.disease,
    this.crop = '',
  });

  @override
  State<DiseaseArticlesScreen> createState() => _DiseaseArticlesScreenState();
}

class _DiseaseArticlesScreenState extends State<DiseaseArticlesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Curated static articles
  List<DiseaseArticle> _curated = [];
  bool _curatedLoading = true;

  // Community posts tab
  List<ForumPost> _articles = [];
  bool _articlesLoading = true;
  int _articlesPage = 1;
  bool _articlesHasMore = true;

  // All posts tab
  List<ForumPost> _posts = [];
  bool _postsLoading = true;
  int _postsPage = 1;
  bool _postsHasMore = true;

  final _articlesScrollCtrl = ScrollController();
  final _postsScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadCurated();
    _loadArticles(refresh: true);
    _loadPosts(refresh: true);
    _articlesScrollCtrl.addListener(_onArticlesScroll);
    _postsScrollCtrl.addListener(_onPostsScroll);
  }

  Future<void> _loadCurated() async {
    final results = await DiseaseArticlesService.getArticles(
      crop: widget.crop,
      disease: widget.disease,
    );
    if (mounted) setState(() { _curated = results; _curatedLoading = false; });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _articlesScrollCtrl.dispose();
    _postsScrollCtrl.dispose();
    super.dispose();
  }

  void _onArticlesScroll() {
    if (_articlesScrollCtrl.position.pixels >=
        _articlesScrollCtrl.position.maxScrollExtent - 200) {
      _loadArticles();
    }
  }

  void _onPostsScroll() {
    if (_postsScrollCtrl.position.pixels >=
        _postsScrollCtrl.position.maxScrollExtent - 200) {
      _loadPosts();
    }
  }

  Future<void> _loadArticles({bool refresh = false}) async {
    if (!_articlesHasMore && !refresh) return;
    if (refresh) {
      _articlesPage = 1;
      _articlesHasMore = true;
    }
    setState(() => _articlesLoading = true);

    final results = await context.read<ForumProvider>().getPostsByFilter(
      contentType: 'article',
      disease: widget.disease,
      crop: widget.crop,
      page: _articlesPage,
    );

    if (mounted) {
      setState(() {
        if (refresh) _articles = results;
        else _articles = [..._articles, ...results];
        if (results.length < 20) _articlesHasMore = false;
        _articlesPage++;
        _articlesLoading = false;
      });
    }
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (!_postsHasMore && !refresh) return;
    if (refresh) {
      _postsPage = 1;
      _postsHasMore = true;
    }
    setState(() => _postsLoading = true);

    final results = await context.read<ForumProvider>().getPostsByFilter(
      disease: widget.disease,
      crop: widget.crop,
      page: _postsPage,
    );

    if (mounted) {
      setState(() {
        if (refresh) _posts = results;
        else _posts = [..._posts, ...results];
        if (results.length < 20) _postsHasMore = false;
        _postsPage++;
        _postsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRTL = lang.isRTL;

    final diseaseName = widget.disease.isNotEmpty
        ? widget.disease
        : (isRTL ? 'المرض' : 'Disease');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRTL ? 'مقالات المجتمع' : 'Community Articles',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              diseaseName,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(
              icon: const Icon(Icons.article_rounded, size: 18),
              text: isRTL ? 'مقالات' : 'Articles',
            ),
            Tab(
              icon: const Icon(Icons.forum_rounded, size: 18),
              text: isRTL ? 'جميع المنشورات' : 'All Posts',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Articles tab — curated resources + community articles
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              await _loadCurated();
              await _loadArticles(refresh: true);
            },
            child: ListView(
              controller: _articlesScrollCtrl,
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // ── Curated articles ──────────────────────────────────────
                if (_curatedLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else if (_curated.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          isRTL ? 'مقالات علمية موصى بها' : 'Curated Scientific Resources',
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._curated.map((a) => _CuratedArticleCard(article: a, isRTL: isRTL)),
                  const Divider(height: 32, indent: 16, endIndent: 16),
                ],

                // ── Community posts ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, color: AppColors.primary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        isRTL ? 'من المجتمع' : 'From the Community',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_articlesLoading && _articles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else if (_articles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                    child: Column(
                      children: [
                        const Icon(Icons.article_outlined, size: 48, color: AppColors.border),
                        const SizedBox(height: 10),
                        Text(
                          isRTL ? 'لا توجد مقالات مجتمعية بعد' : 'No community articles yet',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        Text(
                          isRTL ? 'كن أول من يشارك!' : 'Be the first to share!',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  ..._articles.map((p) => FeedCard(post: p)),
                if (_articlesHasMore && _articles.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                  ),
              ],
            ),
          ),

          // All posts tab
          _PostListView(
            posts: _posts,
            loading: _postsLoading,
            hasMore: _postsHasMore,
            scrollController: _postsScrollCtrl,
            emptyIcon: Icons.chat_bubble_outline_rounded,
            emptyMessage: isRTL
                ? 'لا توجد منشورات حول هذا المرض'
                : 'No posts about this disease yet',
            emptySubtitle: isRTL
                ? 'ناقش مع المجتمع!'
                : 'Start the conversation!',
            onRefresh: () => _loadPosts(refresh: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push(
          '/create-post',
        ),
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: Text(isRTL ? 'شارك خبرتك' : 'Share your experience'),
      ),
    );
  }
}

// ── Curated article card ──────────────────────────────────────────────────────

class _CuratedArticleCard extends StatelessWidget {
  const _CuratedArticleCard({required this.article, required this.isRTL});
  final DiseaseArticle article;
  final bool isRTL;

  Future<void> _open() async {
    final uri = Uri.tryParse(article.url);
    if (uri == null || article.url.isEmpty) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = isRTL && article.titleAr.isNotEmpty ? article.titleAr : article.title;
    return InkWell(
      onTap: _open,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8F5E9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.article_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.summary,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.link, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            article.source,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.open_in_new, size: 13, color: AppColors.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared post-list view ─────────────────────────────────────────────────────

class _PostListView extends StatelessWidget {
  const _PostListView({
    required this.posts,
    required this.loading,
    required this.hasMore,
    required this.scrollController,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.emptySubtitle,
    required this.onRefresh,
  });

  final List<ForumPost> posts;
  final bool loading;
  final bool hasMore;
  final ScrollController scrollController;
  final IconData emptyIcon;
  final String emptyMessage;
  final String emptySubtitle;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading && posts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(emptyIcon, size: 56, color: AppColors.border),
                  const SizedBox(height: 12),
                  Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    emptySubtitle,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: posts.length + (hasMore ? 1 : 0),
        itemBuilder: (ctx, index) {
          if (index == posts.length) {
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
          return FeedCard(post: posts[index]);
        },
      ),
    );
  }
}
