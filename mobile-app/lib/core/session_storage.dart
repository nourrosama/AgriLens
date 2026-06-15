import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _languageKey = 'language_code';
  static const _registeredAtKey = 'registered_at';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<Map<String, dynamic>?> readUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  Future<String?> readLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }

  /// Saves the timestamp of first login (trial start). Never overwrites an
  /// existing value so the trial clock is anchored to the very first login.
  Future<void> saveRegisteredAtIfAbsent(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_registeredAtKey) == null) {
      await prefs.setString(_registeredAtKey, dt.toIso8601String());
    }
  }

  Future<DateTime?> readRegisteredAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_registeredAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
