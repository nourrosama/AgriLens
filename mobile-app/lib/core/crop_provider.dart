import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CropInfo {
  final String value;
  final String labelEn;
  final String labelAr;
  final String emoji;
  final IconData icon;
  final Color color;
  final bool scanEnabled;

  const CropInfo({
    required this.value,
    required this.labelEn,
    required this.labelAr,
    required this.emoji,
    required this.icon,
    required this.color,
    this.scanEnabled = true,
  });
}

class CropProvider extends ChangeNotifier {
  static const List<CropInfo> crops = [
    CropInfo(
      value: 'tomato',
      labelEn: 'Tomato',
      labelAr: 'طماطم',
      emoji: '🍅',
      icon: Icons.local_florist_rounded,
      color: Color(0xFFE53935),
    ),
    CropInfo(
      value: 'potato',
      labelEn: 'Potato',
      labelAr: 'بطاطس',
      emoji: '🥔',
      icon: Icons.eco_rounded,
      color: Color(0xFF8D6E63),
    ),
    CropInfo(
      value: 'apple',
      labelEn: 'Apple',
      labelAr: 'تفاح',
      emoji: '🍎',
      icon: Icons.apple_rounded,
      color: Color(0xFFD81B60),
    ),
    CropInfo(
      value: 'grape',
      labelEn: 'Grape',
      labelAr: 'عنب',
      emoji: '🍇',
      icon: Icons.bubble_chart_rounded,
      color: Color(0xFF7B1FA2),
    ),
    CropInfo(
      value: 'wheat',
      labelEn: 'Wheat',
      labelAr: 'قمح',
      emoji: '🌾',
      icon: Icons.grass_rounded,
      color: Color(0xFFD4A017),
    ),
    CropInfo(
      value: 'mushroom',
      labelEn: 'Mushroom',
      labelAr: 'فطر',
      emoji: '🍄',
      icon: Icons.spa_rounded,
      color: Color(0xFF6D4C41),
    ),
    CropInfo(
      value: 'sugarCane',
      labelEn: 'Sugar Cane',
      labelAr: 'قصب السكر',
      emoji: '🎋',
      icon: Icons.grass_rounded,
      color: Color(0xFF43A047),
      scanEnabled: false,
    ),
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
