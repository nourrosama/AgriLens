import 'dart:io';

class AppConfig {
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    if (_defaultBaseUrl.isNotEmpty) {
      return _defaultBaseUrl;
    }
    if (Platform.isAndroid) {
      return 'http://127.0.0.1:5000';
    }
    return 'http://127.0.0.1:5000';
  }
}
