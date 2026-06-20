import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists session data across app launches.
///
/// Security split:
///   - Auth token  → FlutterSecureStorage (OS keychain / Keystore)
///   - Non-sensitive prefs (language, timestamps, cached user JSON)
///     → SharedPreferences
class SessionStorage {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _languageKey = 'language_code';
  static const _registeredAtKey = 'registered_at';

  // ── Auth token (secure) ──────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() async {
    return _secureStorage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  // ── User profile cache (non-sensitive) ───────────────────────────────────

  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<Map<String, dynamic>?> readUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  // ── Full session clear ───────────────────────────────────────────────────

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  // ── Language preference ──────────────────────────────────────────────────

  Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  Future<String?> readLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }

  // ── Trial clock ──────────────────────────────────────────────────────────

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
