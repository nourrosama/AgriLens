import 'package:flutter/foundation.dart';

import 'api_client.dart';

class Community {
  Community({
    required this.id,
    required this.cropSlug,
    required this.displayName,
    required this.memberCount,
    this.trendingDiseases = const [],
  });

  final String id;
  final String cropSlug;
  final String displayName;
  final int memberCount;
  final List<String> trendingDiseases;

  factory Community.fromJson(Map<String, dynamic> json) => Community(
    id: json['id']?.toString() ?? '',
    cropSlug: json['crop_slug']?.toString() ?? '',
    displayName: json['display_name']?.toString() ?? '',
    memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
    trendingDiseases: List<String>.from(
      (json['trending_diseases'] as List<dynamic>?) ?? [],
    ),
  );
}

class CommunityProvider extends ChangeNotifier {
  CommunityProvider({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;
  List<Community> _communities = [];
  bool _loading = false;
  String? _error;

  List<Community> get communities => List.unmodifiable(_communities);
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadCommunities() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _api.get('/api/communities', auth: true);
      _communities =
          ((response['data'] as Map<String, dynamic>)['communities']
                      as List<dynamic>? ??
                  [])
              .whereType<Map<String, dynamic>>()
              .map(Community.fromJson)
              .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Community?> getCommunity(String cropSlug) async {
    try {
      final response = await _api.get(
        '/api/communities/$cropSlug',
        auth: true,
      );
      return Community.fromJson(
        (response['data'] as Map<String, dynamic>)['community']
            as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> joinCommunity(String cropSlug) async {
    try {
      await _api.post('/api/communities/$cropSlug/join', auth: true);
      await loadCommunities();
    } catch (_) {}
  }

  /// Called automatically after a scan so the user lands in the right community.
  Future<void> autoSubscribeFromScan(String cropType) async {
    if (cropType.isEmpty) return;
    try {
      final slug = cropType.toLowerCase().trim();
      await _api.post('/api/communities/$slug/join', auth: true);
    } catch (_) {}
  }
}
