import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'session_storage.dart';

class LanguageProvider extends ChangeNotifier {
  LanguageProvider({SessionStorage? sessionStorage})
    : _sessionStorage = sessionStorage ?? SessionStorage() {
    _init();
  }

  final SessionStorage _sessionStorage;
  Locale _locale = const Locale('en');
  Map<String, String> _strings = {};
  bool _isReady = false;
  int _loadGeneration = 0;

  Locale get locale => _locale;
  bool get isRTL => _locale.languageCode == 'ar';
  String get languageCode => _locale.languageCode;
  bool get isReady => _isReady;

  Future<void> _init() async {
    final generation = ++_loadGeneration;
    final stored = await _sessionStorage.readLanguage();
    final code = (stored != null && stored.isNotEmpty) ? stored : 'en';
    await _loadLocale(code, generation: generation);
  }

  Future<void> _loadLocale(String code, {int? generation}) async {
    final raw = await rootBundle.loadString('assets/l10n/$code.arb');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    if (generation != null && generation != _loadGeneration) {
      return;
    }
    _strings = {
      for (final e in decoded.entries)
        if (!e.key.startsWith('@')) e.key: e.value.toString(),
    };
    _locale = Locale(code);
    _isReady = true;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    final generation = ++_loadGeneration;
    await _loadLocale(code, generation: generation);
    await _sessionStorage.saveLanguage(code);
  }

  String t(String key) => _strings[key] ?? key;

  /// Converts ASCII digits to Arabic-Indic numerals when in RTL (Arabic) mode.
  String localizeDigits(String s) {
    if (!isRTL) return s;
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic  = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var result = s;
    for (var i = 0; i < western.length; i++) {
      result = result.replaceAll(western[i], arabic[i]);
    }
    return result;
  }

  /// Formats [n] as a localized number string (integer or fixed-decimal).
  String localizeNum(num n, {int? decimals}) => localizeDigits(
        decimals != null ? n.toStringAsFixed(decimals) : n.round().toString(),
      );
}

/// Standalone helper for static/non-widget contexts (e.g. NotificationData).
String localizeDigitsStatic(String s, bool isArabic) {
  if (!isArabic) return s;
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const arabic  = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var result = s;
  for (var i = 0; i < western.length; i++) {
    result = result.replaceAll(western[i], arabic[i]);
  }
  return result;
}
