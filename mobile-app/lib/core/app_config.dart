import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String? _resolvedBaseUrl;

  static String get apiBaseUrl {
    return _resolvedBaseUrl ?? apiBaseUrlCandidates.first;
  }

  static List<String> get apiBaseUrlCandidates {
    if (_defaultBaseUrl.isNotEmpty) {
      return [_defaultBaseUrl];
    }
    if (kIsWeb) {
      return ['http://127.0.0.1:5000'];
    }
    // Android emulator
    return [
      'http://10.0.2.2:5000',
      'http://192.168.191.135:5000',
    ];
  }

  static void setResolvedApiBaseUrl(String baseUrl) {
    _resolvedBaseUrl = baseUrl;
  }

  static String resolveMediaUrl(String pathOrUrl) {
    if (pathOrUrl.isEmpty) return pathOrUrl;
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    final normalizedPath = pathOrUrl.startsWith('/')
        ? pathOrUrl
        : '/$pathOrUrl';
    final base = Uri.parse(apiBaseUrl);
    return base.replace(path: normalizedPath, queryParameters: null).toString();
  }
}