import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/forum_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';

/// "From the Community" card shown at the bottom of the scan result screen.
/// Lazily fetches 3 relevant posts based on the crop type and detected disease.
class PostScanCommunityCard extends StatefulWidget {
  const PostScanCommunityCard({
    super.key,
    required this.cropType,
    required this.disease,
  });

  final String cropType;
  final String disease;

  @override
  State<PostScanCommunityCard> createState() => _PostScanCommunityCardState();
}

class _PostScanCommunityCardState extends State<PostScanCommunityCard> {
  List<ForumPost>? _posts;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final forum = context.read<ForumProvider>();
      final posts = await forum.getPostScanSuggestions(
        cropType: widget.cropType,
        disease: widget.disease,
      );
      if (mounted) setState(() => _posts = posts);
    } catch (_) {
      if (mounted) setState(() => _posts = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRTL = lang.isRTL;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.people_alt_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isRTL ? 'من مجتمع المزارعين' : 'From the Community',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    final params = <String, String>{};
                    if (widget.disease.isNotEmpty) params['disease'] = widget.disease;
                    if (widget.cropType.isNotEmpty) params['crop'] = widget.cropType;
                    final query = params.entries
                        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
                        .join('&');
                    context.push('/disease-articles${query.isNotEmpty ? '?$query' : ''}');
                  },
                  child: Text(
                    isRTL ? 'المزيد ←' : 'See more →',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_posts == null || _posts!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  isRTL
                      ? 'لا توجد منشورات ذات صلة بعد'
                      : 'No related posts yet — be the first to share!',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              )
            else
              Column(
                children: _posts!
                    .map((post) => _MiniPostTile(post: post))
                    .toList(),
              ),

            const SizedBox(height: 8),
            // Disease articles button (only when a disease is known)
            if (widget.disease.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final params = <String, String>{'disease': widget.disease};
                    if (widget.cropType.isNotEmpty) params['crop'] = widget.cropType;
                    final query = params.entries
                        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
                        .join('&');
                    context.push('/disease-articles?$query');
                  },
                  icon: const Icon(Icons.article_rounded, size: 18),
                  label: Text(
                    isRTL
                        ? 'مقالات عن هذا المرض'
                        : 'Articles about this disease',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Open Forum button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/feed'),
                icon: const Icon(Icons.forum_rounded, size: 18),
                label: Text(
                  isRTL ? 'فتح المنتدى الزراعي' : 'Open Farmer Forum',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPostTile extends StatelessWidget {
  const _MiniPostTile({required this.post});
  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.circle,
            size: 6,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              post.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
