import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class ForumPost {
  ForumPost({
    required this.id,
    required this.authorId,
    required this.body,
    required this.contentType,
    required this.mediaUrl,
    required this.likesCount,
    required this.commentsCount,
    required this.likedByMe,
    required this.createdAt,
    this.cropTags = const [],
    this.diseaseTags = const [],
    this.authorName = '',
    this.authorPhotoUrl = '',
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String body;
  final String contentType; // post | video | article | blog
  final String mediaUrl;
  int likesCount;
  final int commentsCount;
  bool likedByMe;
  final DateTime createdAt;
  final List<String> cropTags;
  final List<String> diseaseTags;

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    final tags = (json['tags'] as Map<String, dynamic>?) ?? {};
    return ForumPost(
      id: json['id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? '',
      authorPhotoUrl: json['author_photo_url']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      contentType: json['content_type']?.toString() ?? 'post',
      mediaUrl: json['media_url']?.toString() ?? '',
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] == true,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      cropTags: List<String>.from(
        (tags['crops'] as List<dynamic>?) ?? [],
      ),
      diseaseTags: List<String>.from(
        (tags['diseases'] as List<dynamic>?) ?? [],
      ),
    );
  }
}

class ForumComment {
  ForumComment({
    required this.id,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.authorName = '',
    this.authorPhotoUrl = '',
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String body;
  final DateTime createdAt;

  factory ForumComment.fromJson(Map<String, dynamic> json) => ForumComment(
    id: json['id']?.toString() ?? '',
    authorId: json['author_id']?.toString() ?? '',
    authorName: json['author_name']?.toString() ?? '',
    authorPhotoUrl: json['author_photo_url']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
  );
}

class ForumQuestion {
  ForumQuestion({
    required this.id,
    required this.authorId,
    required this.title,
    required this.body,
    required this.answerCount,
    required this.isResolved,
    required this.createdAt,
    this.cropTags = const [],
    this.diseaseTags = const [],
    this.authorName = '',
    this.authorPhotoUrl = '',
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String title;
  final String body;
  final int answerCount;
  final bool isResolved;
  final DateTime createdAt;
  final List<String> cropTags;
  final List<String> diseaseTags;

  factory ForumQuestion.fromJson(Map<String, dynamic> json) {
    final tags = (json['tags'] as Map<String, dynamic>?) ?? {};
    return ForumQuestion(
      id: json['id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? '',
      authorPhotoUrl: json['author_photo_url']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      answerCount: (json['answer_count'] as num?)?.toInt() ?? 0,
      isResolved: json['is_resolved'] == true,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      cropTags: List<String>.from(
        (tags['crops'] as List<dynamic>?) ?? [],
      ),
      diseaseTags: List<String>.from(
        (tags['diseases'] as List<dynamic>?) ?? [],
      ),
    );
  }
}

class ForumAnswer {
  ForumAnswer({
    required this.id,
    required this.authorId,
    required this.body,
    required this.isAccepted,
    required this.upvotes,
    required this.createdAt,
    this.authorName = '',
    this.authorPhotoUrl = '',
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorPhotoUrl;
  final String body;
  bool isAccepted;
  final int upvotes;
  final DateTime createdAt;

  factory ForumAnswer.fromJson(Map<String, dynamic> json) => ForumAnswer(
    id: json['id']?.toString() ?? '',
    authorId: json['author_id']?.toString() ?? '',
    authorName: json['author_name']?.toString() ?? '',
    authorPhotoUrl: json['author_photo_url']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    isAccepted: json['is_accepted'] == true,
    upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
  );
}

// ── Provider ──────────────────────────────────────────────────────────────────

class ForumProvider extends ChangeNotifier {
  ForumProvider({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  // Feed state
  final List<ForumPost> _feed = [];
  bool _feedLoading = false;
  bool _feedHasMore = true;
  int _feedPage = 1;
  String? _feedError;

  List<ForumPost> get feed => List.unmodifiable(_feed);
  bool get feedLoading => _feedLoading;
  bool get feedHasMore => _feedHasMore;
  String? get feedError => _feedError;

  // ── Feed ────────────────────────────────────────────────────────────────────

  static const _feedCacheKey = 'cached_forum_feed_v1';

  Future<void> loadFeed({bool refresh = false}) async {
    if (_feedLoading) return;
    if (refresh) {
      _feedPage = 1;
      _feedHasMore = true;
      _feed.clear();
    }
    if (!_feedHasMore) return;
    _feedLoading = true;
    _feedError = null;
    notifyListeners();
    final isFirstPage = _feedPage == 1;
    try {
      final response = await _api.get(
        '/api/feed',
        auth: true,
        query: {'page': _feedPage, 'per_page': 20},
      );
      final data = response['data'] as Map<String, dynamic>;
      final rawPosts =
          ((data['posts'] as List<dynamic>?) ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
      final posts = rawPosts.map(ForumPost.fromJson).toList();
      if (posts.length < 20) _feedHasMore = false;
      _feed.addAll(posts);
      _feedPage++;
      // Persist page 1 for offline use
      if (isFirstPage) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_feedCacheKey, jsonEncode(rawPosts));
      }
    } catch (e) {
      // Load cached feed when offline and no posts loaded yet
      if (isFirstPage && _feed.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final cached = prefs.getString(_feedCacheKey);
          if (cached != null) {
            final rawPosts = (jsonDecode(cached) as List<dynamic>)
                .whereType<Map<String, dynamic>>()
                .toList();
            _feed.addAll(rawPosts.map(ForumPost.fromJson));
            _feedHasMore = false;
          }
        } catch (_) {}
      }
      _feedError = e.toString();
    } finally {
      _feedLoading = false;
      notifyListeners();
    }
  }

  // ── Post actions ─────────────────────────────────────────────────────────────

  Future<void> toggleLike(String postId) async {
    try {
      final response = await _api.post(
        '/api/posts/$postId/like',
        auth: true,
      );
      final data = response['data'] as Map<String, dynamic>;
      final idx = _feed.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        _feed[idx].likedByMe = data['liked'] == true;
        _feed[idx].likesCount =
            (data['likes_count'] as num?)?.toInt() ?? _feed[idx].likesCount;
        notifyListeners();
      }
    } catch (_) {}
  }

  // Holds the last error message so the UI can display it if needed.
  String? _createPostError;
  String? get createPostError => _createPostError;

  Future<ForumPost?> createPost({
    required String body,
    String contentType = 'post',
    String mediaUrl = '',
    List<String> cropTags = const [],
    List<String> diseaseTags = const [],
  }) async {
    _createPostError = null;
    try {
      final response = await _api.post(
        '/api/posts',
        auth: true,
        body: {
          'body': body,
          'content_type': contentType,
          'media_url': mediaUrl,
          'crop_tags': cropTags,
          'disease_tags': diseaseTags,
        },
      );
      final data = response['data'];
      if (data == null) {
        _createPostError = 'Server returned no data';
        return null;
      }
      final postJson = (data as Map<String, dynamic>)['post'];
      if (postJson == null) {
        _createPostError = 'Server response missing post field';
        return null;
      }
      final post = ForumPost.fromJson(postJson as Map<String, dynamic>);
      _feed.insert(0, post);
      notifyListeners();
      return post;
    } catch (e) {
      _createPostError = e.toString();
      debugPrint('createPost error: $e');
      return null;
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      await _api.delete('/api/posts/$postId', auth: true);
      _feed.removeWhere((p) => p.id == postId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Comments ────────────────────────────────────────────────────────────────

  Future<List<ForumComment>> getComments(String postId) async {
    try {
      final response = await _api.get(
        '/api/posts/$postId/comments',
        auth: true,
      );
      return ((response['data'] as Map<String, dynamic>)['comments']
                  as List<dynamic>? ??
              [])
          .whereType<Map<String, dynamic>>()
          .map(ForumComment.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<ForumComment?> addComment(String postId, String body) async {
    try {
      final response = await _api.post(
        '/api/posts/$postId/comments',
        auth: true,
        body: {'body': body},
      );
      return ForumComment.fromJson(
        (response['data'] as Map<String, dynamic>)['comment']
            as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Q&A ─────────────────────────────────────────────────────────────────────

  Future<List<ForumQuestion>> getQuestions({
    String crop = '',
    String disease = '',
    String filter = '',
    int page = 1,
  }) async {
    try {
      final q = <String, dynamic>{'page': page};
      if (crop.isNotEmpty) q['crop'] = crop;
      if (disease.isNotEmpty) q['disease'] = disease;
      if (filter.isNotEmpty) q['filter'] = filter;
      final response = await _api.get(
        '/api/forum/questions',
        auth: true,
        query: q,
      );
      return ((response['data'] as Map<String, dynamic>)['questions']
                  as List<dynamic>? ??
              [])
          .whereType<Map<String, dynamic>>()
          .map(ForumQuestion.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<ForumQuestion?> askQuestion({
    required String title,
    required String body,
    List<String> cropTags = const [],
    List<String> diseaseTags = const [],
  }) async {
    try {
      final response = await _api.post(
        '/api/forum/questions',
        auth: true,
        body: {
          'title': title,
          'body': body,
          'crop_tags': cropTags,
          'disease_tags': diseaseTags,
        },
      );
      return ForumQuestion.fromJson(
        (response['data'] as Map<String, dynamic>)['question']
            as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<({ForumQuestion? question, List<ForumAnswer> answers})> getQuestion(
    String questionId,
  ) async {
    try {
      final response = await _api.get(
        '/api/forum/questions/$questionId',
        auth: true,
      );
      final data = response['data'] as Map<String, dynamic>;
      final question = ForumQuestion.fromJson(
        data['question'] as Map<String, dynamic>,
      );
      final answers =
          ((data['answers'] as List<dynamic>?) ?? [])
              .whereType<Map<String, dynamic>>()
              .map(ForumAnswer.fromJson)
              .toList();
      return (question: question, answers: answers);
    } catch (_) {
      return (question: null, answers: <ForumAnswer>[]);
    }
  }

  Future<ForumAnswer?> postAnswer(String questionId, String body) async {
    try {
      final response = await _api.post(
        '/api/forum/questions/$questionId/answers',
        auth: true,
        body: {'body': body},
      );
      return ForumAnswer.fromJson(
        (response['data'] as Map<String, dynamic>)['answer']
            as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> acceptAnswer(String answerId, String questionId) async {
    try {
      await _api.put(
        '/api/forum/answers/$answerId/accept',
        auth: true,
        body: {'question_id': questionId},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Filtered posts (my posts, etc.) ─────────────────────────────────────────

  Future<List<ForumPost>> getFilteredPosts({
    String filter = '',
    int page = 1,
  }) async {
    try {
      final q = <String, dynamic>{'page': page};
      if (filter.isNotEmpty) q['filter'] = filter;
      final response = await _api.get('/api/posts', auth: true, query: q);
      return ((response['data'] as Map<String, dynamic>)['posts']
                  as List<dynamic>? ??
              [])
          .whereType<Map<String, dynamic>>()
          .map(ForumPost.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Post-scan suggestions ────────────────────────────────────────────────────

  Future<List<ForumPost>> getPostScanSuggestions({
    required String cropType,
    required String disease,
  }) async {
    try {
      final response = await _api.get(
        '/api/feed/post-scan',
        auth: true,
        query: {'crop_type': cropType, 'disease': disease},
      );
      return ((response['data'] as Map<String, dynamic>)['posts']
                  as List<dynamic>? ??
              [])
          .whereType<Map<String, dynamic>>()
          .map(ForumPost.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Trending ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getTrending() async {
    try {
      final response = await _api.get('/api/feed/trending', auth: true);
      return (response['data'] as Map<String, dynamic>?) ?? {};
    } catch (_) {
      return {};
    }
  }

  // ── Media upload ──────────────────────────────────────────────────────────────

  /// Upload a local file (image / video / pdf) and return the hosted media_url.
  /// Returns null on failure.
  Future<String?> uploadMedia(File file) async {
    try {
      final response = await _api.multipart(
        '/api/forum/upload',
        file: file,
        fieldName: 'file',
        auth: true,
        timeout: const Duration(seconds: 60),
      );
      return (response['data'] as Map<String, dynamic>)['media_url']
          ?.toString();
    } catch (_) {
      return null;
    }
  }

  // ── Filtered posts (articles / disease pages) ─────────────────────────────────

  /// Fetch posts filtered by optional [contentType] and/or [disease] tag.
  Future<List<ForumPost>> getPostsByFilter({
    String contentType = '',
    String disease = '',
    String crop = '',
    int page = 1,
  }) async {
    try {
      final query = <String, dynamic>{'page': page};
      if (contentType.isNotEmpty) query['content_type'] = contentType;
      if (disease.isNotEmpty) query['disease'] = disease;
      if (crop.isNotEmpty) query['crop'] = crop;
      final response = await _api.get(
        '/api/posts',
        auth: true,
        query: query,
      );
      return ((response['data'] as Map<String, dynamic>)['posts']
                  as List<dynamic>? ??
              [])
          .whereType<Map<String, dynamic>>()
          .map(ForumPost.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
