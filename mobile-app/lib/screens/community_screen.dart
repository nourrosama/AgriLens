import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/community_provider.dart';
import 'package:agrilens/core/forum_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/widgets/feed_card.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, required this.cropSlug});
  final String cropSlug;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  Community? _community;
  List<ForumPost> _posts = [];
  bool _loading = true;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final community =
        await context.read<CommunityProvider>().getCommunity(widget.cropSlug);
    final posts = await context.read<ForumProvider>().getPostScanSuggestions(
      cropType: widget.cropSlug,
      disease: '',
    );
    if (mounted) {
      setState(() {
        _community = community;
        _posts = posts;
        _loading = false;
      });
    }
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    await context.read<CommunityProvider>().joinCommunity(widget.cropSlug);
    if (mounted) {
      setState(() => _joining = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRTL = lang.isRTL;
    final displayName = _community?.displayName ?? widget.cropSlug;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_loading && _community != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _joining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : OutlinedButton(
                      onPressed: _join,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      child: Text(
                        isRTL ? 'انضمام' : 'Join',
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                children: [
                  // Community header
                  if (_community != null)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.eco_rounded,
                            color: AppColors.primaryDark,
                            size: 32,
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              Text(
                                '${_community!.memberCount} ${isRTL ? "عضو" : "members"}',
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Recent posts in this community
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Text(
                      isRTL ? 'المنشورات الأخيرة' : 'Recent Posts',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),

                  if (_posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No posts in this community yet',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    for (final post in _posts) FeedCard(post: post),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}
