import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CropInfo {
  final String value;
  final String labelEn;
  final String labelAr;
  final String emoji;

  const CropInfo({
    required this.value,
    required this.labelEn,
    required this.labelAr,
    required this.emoji,
  });
}

class CropProvider extends ChangeNotifier {
  static const List<CropInfo> crops = [
    CropInfo(value: 'tomato', labelEn: 'Tomato', labelAr: 'Tomato', emoji: 'T'),
    CropInfo(value: 'potato', labelEn: 'Potato', labelAr: 'Potato', emoji: 'P'),
    CropInfo(value: 'apple', labelEn: 'Apple', labelAr: 'Apple', emoji: 'A'),
  ];

  String _selectedCrop = '';
  bool _isLoaded = false;

  String get selectedCrop => _selectedCrop;
  bool get isLoaded => _isLoaded;
  bool get hasCropSelected => _selectedCrop.isNotEmpty;

  CropInfo? get selectedCropInfo {
    if (_selectedCrop.isEmpty) return null;
    return crops.firstWhere(
      (c) => c.value == _selectedCrop,
      orElse: () => crops.first,
    );
  }

  CropProvider() {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCrop = prefs.getString('selected_crop') ?? crops.first.value;
    _selectedCrop = crops.any((crop) => crop.value == savedCrop)
        ? savedCrop
        : crops.first.value;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> selectCrop(String cropValue) async {
    _selectedCrop = crops.any((crop) => crop.value == cropValue)
        ? cropValue
        : crops.first.value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_crop', _selectedCrop);
  }

  void clearCrop() {
    _selectedCrop = '';
    notifyListeners();
  }

  String getLabel(String cropValue, {bool isRTL = false}) {
    final crop = crops.firstWhere(
      (c) => c.value == cropValue,
      orElse: () => crops.first,
    );
    return isRTL ? crop.labelAr : crop.labelEn;
  }
}
