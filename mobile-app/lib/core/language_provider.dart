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
}
