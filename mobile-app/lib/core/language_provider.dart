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

  Locale get locale => _locale;
  bool get isRTL => _locale.languageCode == 'ar';
  String get languageCode => _locale.languageCode;
  bool get isReady => _isReady;

  Future<void> _init() async {
    final stored = await _sessionStorage.readLanguage();
    final code = (stored != null && stored.isNotEmpty) ? stored : 'en';
    await _loadLocale(code);
  }

  Future<void> _loadLocale(String code) async {
    final raw = await rootBundle.loadString('assets/l10n/$code.arb');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _strings = {
      for (final e in decoded.entries)
        if (!e.key.startsWith('@')) e.key: e.value.toString(),
    };
    _locale = Locale(code);
    _isReady = true;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    await _loadLocale(code);
    await _sessionStorage.saveLanguage(code);
  }

  String t(String key) => _strings[key] ?? key;
}
