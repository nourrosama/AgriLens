import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores bookmarked disease IDs in SharedPreferences.
class FavouritesProvider extends ChangeNotifier {
  FavouritesProvider() {
    _load();
  }

  static const _key = 'favourite_diseases';
  List<String> _ids = [];

  List<String> get ids => List.unmodifiable(_ids);

  bool isFavourite(String diseaseId) => _ids.contains(diseaseId);

  Future<void> toggle(String diseaseId) async {
    if (_ids.contains(diseaseId)) {
      _ids.remove(diseaseId);
    } else {
      _ids.add(diseaseId);
    }
    notifyListeners();
    await _save();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _ids = prefs.getStringList(_key) ?? [];
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids);
  }
}
