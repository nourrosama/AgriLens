import 'package:flutter/material.dart';

/// Data model for a field
class FieldData {
  final int id;
  String name;
  String location;
  String area;
  String? cropType;
  String? soilType;
  String? irrigationType;
  String status; // 'healthy' | 'warning'
  int health; // 0-100

  FieldData({
    required this.id,
    required this.name,
    required this.location,
    required this.area,
    this.cropType,
    this.soilType,
    this.irrigationType,
    this.status = 'healthy',
    this.health = 85,
  });
}

/// Provider that manages the list of fields.
/// Supports add, update, and delete operations.
class FieldsProvider extends ChangeNotifier {
  int _nextId = 4;

  final List<FieldData> _fields = [
    FieldData(
      id: 1,
      name: 'Field A',
      location: 'North Section',
      area: '2.5',
      cropType: 'tomatoes',
      soilType: 'loamy',
      irrigationType: 'drip',
      status: 'healthy',
      health: 92,
    ),
    FieldData(
      id: 2,
      name: 'Field B',
      location: 'East Section',
      area: '3.2',
      cropType: 'wheat',
      soilType: 'clay',
      irrigationType: 'sprinkler',
      status: 'warning',
      health: 68,
    ),
    FieldData(
      id: 3,
      name: 'Field C',
      location: 'South Section',
      area: '1.8',
      cropType: 'corn',
      soilType: 'sandy',
      irrigationType: 'surface',
      status: 'healthy',
      health: 88,
    ),
  ];

  List<FieldData> get fields => List.unmodifiable(_fields);

  FieldData? getField(int id) {
    try {
      return _fields.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  void addField({
    required String name,
    required String location,
    required String area,
    String? cropType,
    String? soilType,
    String? irrigationType,
  }) {
    _fields.add(FieldData(
      id: _nextId++,
      name: name,
      location: location,
      area: area,
      cropType: cropType,
      soilType: soilType,
      irrigationType: irrigationType,
      status: 'healthy',
      health: 85,
    ));
    notifyListeners();
  }

  void updateField(int id, {
    String? name,
    String? location,
    String? area,
    String? cropType,
    String? soilType,
    String? irrigationType,
  }) {
    final field = getField(id);
    if (field == null) return;
    if (name != null) field.name = name;
    if (location != null) field.location = location;
    if (area != null) field.area = area;
    if (cropType != null) field.cropType = cropType;
    if (soilType != null) field.soilType = soilType;
    if (irrigationType != null) field.irrigationType = irrigationType;
    notifyListeners();
  }

  void deleteField(int id) {
    _fields.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  /// Computed stats
  double get totalArea {
    double total = 0;
    for (final f in _fields) {
      total += double.tryParse(f.area) ?? 0;
    }
    return total;
  }

  int get averageHealth {
    if (_fields.isEmpty) return 0;
    final sum = _fields.fold<int>(0, (s, f) => s + f.health);
    return (sum / _fields.length).round();
  }
}
