import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'session_storage.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({SessionStorage? sessionStorage, http.Client? httpClient})
    : _sessionStorage = sessionStorage ?? SessionStorage(),
      _httpClient = httpClient ?? http.Client();

  final SessionStorage _sessionStorage;
  final http.Client _httpClient;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(AppConfig.apiBaseUrl);
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
    final response = await _httpClient.get(
      _uri(path, query),
      headers: await _headers(auth: auth),
    ).timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    bool auth = false,
    Map<String, dynamic>? body,
  }) async {
    print('\n🚀 ====== SENDING POST TO: ${_uri(path)} ====== 🚀\n');
    final response = await _httpClient.post(
      _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(body ?? const {}),
    ).timeout(const Duration(seconds: 15));
    print('\n✅ ====== RECEIVING POST FROM: ${_uri(path)} ====== ✅\n');
    return _decode(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    bool auth = false,
    Map<String, dynamic>? body,
  }) async {
    final response = await _httpClient.put(
      _uri(path),
      headers: await _headers(auth: auth),
      body: jsonEncode(body ?? const {}),
    ).timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  Future<Map<String, dynamic>> delete(String path, {bool auth = false}) async {
    final response = await _httpClient.delete(
      _uri(path),
      headers: await _headers(auth: auth),
    ).timeout(const Duration(seconds: 15));
    return _decode(response);
  }

  Future<Map<String, dynamic>> multipart(
    String path, {
    required File file,
    required String fieldName,
    bool auth = false,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll(await _headers(auth: auth, json: false));
    request.fields.addAll(fields ?? const {});
    request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));
    final response = await http.Response.fromStream(await request.send());
    return _decode(response);
  }

  Future<Map<String, String>> _headers({
    required bool auth,
    bool json = true,
  }) async {
    final headers = <String, String>{};
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
    final decoded = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};
    if (response.statusCode >= 400) {
      throw ApiException(
        decoded['message']?.toString() ?? 'Request failed',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }
}
