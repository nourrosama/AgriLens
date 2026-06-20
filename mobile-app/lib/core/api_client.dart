import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'session_storage.dart';

class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.isConnectivityError = false,
    this.errorCode,
    this.body,
  });

  final String message;
  final int? statusCode;
  final bool isConnectivityError;
  final String? errorCode;
  final Map<String, dynamic>? body;

  Map<String, dynamic>? get data {
    final value = body?['data'];
    return value is Map<String, dynamic> ? value : null;
  }

  Map<String, dynamic>? get validation {
    final value = data?['validation'] ?? body?['validation'];
    return value is Map<String, dynamic> ? value : null;
  }

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({SessionStorage? sessionStorage, http.Client? httpClient})
    : _sessionStorage = sessionStorage ?? SessionStorage(),
      _httpClient = httpClient ?? http.Client();

  final SessionStorage _sessionStorage;
  final http.Client _httpClient;

  Uri _uri(String baseUrl, String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: path,
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Future<Map<String, dynamic>> get(
    String path, {
    bool auth = false,
    Map<String, dynamic>? query,
  }) async {
    final headers = await _headers(auth: auth);
    final response = await _sendWithFallback(
      (baseUrl) =>
          _httpClient.get(_uri(baseUrl, path, query), headers: headers),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    bool auth = false,
    Map<String, dynamic>? body,
  }) async {
    final headers = await _headers(auth: auth);
    final response = await _sendWithFallback(
      (baseUrl) => _httpClient.post(
        _uri(baseUrl, path),
        headers: headers,
        body: jsonEncode(body ?? const {}),
      ),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    bool auth = false,
    Map<String, dynamic>? body,
  }) async {
    final headers = await _headers(auth: auth);
    final response = await _sendWithFallback(
      (baseUrl) => _httpClient.put(
        _uri(baseUrl, path),
        headers: headers,
        body: jsonEncode(body ?? const {}),
      ),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = false,
    Map<String, dynamic>? body,
  }) async {
    final headers = await _headers(auth: auth);
    final response = await _sendWithFallback(
      (baseUrl) => _httpClient.delete(
        _uri(baseUrl, path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> multipart(
    String path, {
    required File file,
    required String fieldName,
    bool auth = false,
    Map<String, String>? fields,
    String method = 'POST',
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final headers = await _headers(auth: auth, json: false);
    final streamedResponse = await _sendWithFallback((baseUrl) async {
      final request = http.MultipartRequest(method, _uri(baseUrl, path));
      request.headers.addAll(headers);
      request.fields.addAll(fields ?? const {});
      request.files.add(
        await http.MultipartFile.fromPath(fieldName, file.path),
      );
      return request.send();
    }, timeout: timeout);
    final response = await http.Response.fromStream(streamedResponse);
    return _decode(response);
  }

  Future<Map<String, dynamic>> multipartBytes(
    String path, {
    required Uint8List bytes,
    required String filename,
    required String fieldName,
    bool auth = false,
    Map<String, String>? fields,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final headers = await _headers(auth: auth, json: false);
    final streamedResponse = await _sendWithFallback((baseUrl) async {
      final request = http.MultipartRequest('POST', _uri(baseUrl, path));
      request.headers.addAll(headers);
      request.fields.addAll(fields ?? const {});
      request.files.add(
        http.MultipartFile.fromBytes(fieldName, bytes, filename: filename),
      );
      return request.send();
    }, timeout: timeout);
    final response = await http.Response.fromStream(streamedResponse);
    return _decode(response);
  }

  Future<T> _sendWithFallback<T>(
    Future<T> Function(String baseUrl) request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    ApiException? lastError;

    for (final baseUrl in AppConfig.apiBaseUrlCandidates) {
      try {
        final response = await _runRequest(
          () => request(baseUrl),
          timeout: timeout,
        );
        AppConfig.setResolvedApiBaseUrl(baseUrl);
        return response;
      } on ApiException catch (error) {
        lastError = error;
        if (!error.isConnectivityError) {
          rethrow;
        }
      }
    }

    throw lastError ??
        ApiException(
          'Unable to reach the server. Check that the backend is running and that API_BASE_URL points to the correct host for this device.',
          isConnectivityError: true,
        );
  }

  Future<T> _runRequest<T>(
    Future<T> Function() request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check that the backend is running and that API_BASE_URL points to the correct host for this device.',
        isConnectivityError: true,
      );
    } on SocketException {
      throw ApiException(
        'Unable to reach the server. Check that the backend is running and that API_BASE_URL points to the correct host for this device.',
        isConnectivityError: true,
      );
    } on http.ClientException catch (error) {
      final message = error.message.toLowerCase();
      throw ApiException(
        'Unable to reach the server. Check that the backend is running and that API_BASE_URL points to the correct host for this device.',
        isConnectivityError:
            message.contains('cleartext') ||
            message.contains('failed host lookup') ||
            message.contains('connection refused') ||
            message.contains('failed to fetch'),
      );
    }
  }

  Future<Map<String, String>> _headers({
    required bool auth,
    bool json = true,
  }) async {
    final headers = <String, String>{'ngrok-skip-browser-warning': 'true'};
    if (json) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }
    if (auth) {
      final token = await _sessionStorage.readToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> decoded;
    try {
      decoded = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
    } on FormatException {
      // Server returned non-JSON (HTML error page, nginx 502, etc.)
      throw ApiException(
        'Server returned an unexpected response (status ${response.statusCode}). '
        'The backend may be down or unreachable.',
        statusCode: response.statusCode,
        isConnectivityError: response.statusCode >= 500 || response.statusCode == 0,
      );
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        decoded['message']?.toString() ?? 'Request failed',
        statusCode: response.statusCode,
        errorCode: decoded['error_code']?.toString(),
        body: decoded,
      );
    }
    return decoded;
  }
}
