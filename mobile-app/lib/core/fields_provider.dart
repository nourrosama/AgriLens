import 'package:flutter/foundation.dart';

import 'api_client.dart';

class FieldData {
  FieldData({
    required this.id,
    required this.farmId,
    required this.name,
    required this.location,
    required this.area,
    this.cropType,
    this.soilType,
    this.irrigationType,
    this.season,
    this.status = 'healthy',
    this.health = 85,
    this.farmName = '',
    this.locationData = const {},
    this.weatherSnapshot = const {},
  });

  final String id;
  final String farmId;
  final String farmName;
  final Map<String, dynamic> locationData;
  final Map<String, dynamic> weatherSnapshot;
  String name;
  String location;
  String area;
  String? cropType;
  String? soilType;
  String? irrigationType;
  String? season;
  String status;
  int health;
  double? get latitude =>
      _toDouble(locationData['lat'] ?? locationData['latitude']);
  double? get longitude => _toDouble(
    locationData['lng'] ?? locationData['lon'] ?? locationData['longitude'],
  );

  factory FieldData.fromJson(
    Map<String, dynamic> json, {
    required String farmId,
    required String farmName,
  }) {
    final healthScore = (json['health_score'] as num?)?.round() ?? 0;
    final riskLevel = json['risk_level']?.toString() ?? 'low';
    final location = json['location'];
    String locationLabel = '';
    if (location is Map<String, dynamic>) {
      locationLabel =
          location['label']?.toString() ??
          '${location['lat'] ?? ''}${location.containsKey('lng') ? ', ${location['lng']}' : ''}';
    } else if (location != null) {
      locationLabel = location.toString();
    }
    return FieldData(
      id: json['field_id']?.toString() ?? '',
      farmId: farmId,
      farmName: farmName,
      name: json['name']?.toString() ?? '',
      location: locationLabel,
      area: (json['area_hectares'] ?? '').toString(),
      cropType: json['crop_type']?.toString(),
      soilType: json['soil_type']?.toString(),
      irrigationType: json['irrigation_type']?.toString(),
      season: json['season']?.toString(),
      status: riskLevel == 'low' ? 'healthy' : 'warning',
      health: healthScore,
      locationData: location is Map<String, dynamic> ? location : const {},
      weatherSnapshot: json['weather_snapshot'] is Map<String, dynamic>
          ? json['weather_snapshot'] as Map<String, dynamic>
          : const {},
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}

class FieldsProvider extends ChangeNotifier {
  FieldsProvider({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;
  final List<FieldData> _fields = [];
  List<Map<String, dynamic>> _farms = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentUserId = '';

  List<FieldData> get fields => List.unmodifiable(_fields);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get farms => List.unmodifiable(_farms);
  String get currentUserId => _currentUserId;

  void clear() {
    _fields.clear();
    _farms.clear();
    _errorMessage = null;
    notifyListeners();
  }

  void onUserChanged(String userId) {
    if (userId == _currentUserId) return;
    _currentUserId = userId;
    if (userId.isEmpty) {
      clear();
    } else {
      loadFields();
    }
  }

  FieldData? getField(String id) {
    try {
      return _fields.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadFields() async {
    _setLoading(true);
    try {
      final response = await _apiClient.get('/api/farms', auth: true);
      final farmsJson =
          ((response['data'] as Map<String, dynamic>)['farms']
                      as List<dynamic>? ??
                  [])
              .cast<Map<String, dynamic>>();
      _farms = farmsJson;
      _fields
        ..clear()
        ..addAll(
          farmsJson.expand((farm) {
            final farmId = farm['id']?.toString() ?? '';
            final farmName = farm['name']?.toString() ?? 'Farm';
            final fieldsJson = (farm['fields'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();
            return fieldsJson.map(
              (field) =>
                  FieldData.fromJson(field, farmId: farmId, farmName: farmName),
            );
          }),
        );
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addField({
    required String name,
    required String location,
    required String area,
    double? latitude,
    double? longitude,
    String? cropType,
    String? soilType,
    String? irrigationType,
    String? season,
  }) async {
    _setLoading(true);
    try {
      final locationPayload = {
        'label': location,
        'lat': ?latitude,
        'lng': ?longitude,
      };
      final farmId = await _ensureFarm(locationPayload);
      await _apiClient.post(
        '/api/farms/$farmId/fields',
        auth: true,
        body: {
          'name': name,
          'crop_type': cropType ?? '',
          'area_hectares': double.tryParse(area) ?? 0,
          'location': locationPayload,
          'soil_type': soilType ?? '',
          'irrigation_type': irrigationType ?? '',
          'season': season ?? '',
          'health_score': 85,
          'risk_level': 'low',
        },
      );
      await loadFields();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateField(
    String id, {
    String? name,
    String? location,
    String? area,
    double? latitude,
    double? longitude,
    String? cropType,
    String? soilType,
    String? irrigationType,
    String? season,
  }) async {
    final field = getField(id);
    if (field == null) {
      return;
    }
    _setLoading(true);
    try {
      await _apiClient.put(
        '/api/farms/${field.farmId}/fields/$id',
        auth: true,
        body: {
          ...?(name == null ? null : {'name': name}),
          ...?(cropType == null ? null : {'crop_type': cropType}),
          ...?(area == null
              ? null
              : {'area_hectares': double.tryParse(area) ?? 0}),
          ...?(location == null
              ? null
              : {
                  'location': {'label': location},
                }),
          ...?(latitude == null && longitude == null
              ? null
              : {
                  'location': {
                    'label': location ?? field.location,
                    'lat': ?latitude,
                    'lng': ?longitude,
                  },
                }),
          ...?(soilType == null ? null : {'soil_type': soilType}),
          ...?(irrigationType == null
              ? null
              : {'irrigation_type': irrigationType}),
          ...?(season == null ? null : {'season': season}),
        },
      );
      await loadFields();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteField(String id) async {
    final field = getField(id);
    if (field == null) {
      return;
    }
    _setLoading(true);
    try {
      await _apiClient.delete(
        '/api/farms/${field.farmId}/fields/$id',
        auth: true,
      );
      await loadFields();
    } finally {
      _setLoading(false);
    }
  }

  double get totalArea {
    double total = 0;
    for (final field in _fields) {
      total += double.tryParse(field.area) ?? 0;
    }
    return total;
  }

  int get averageHealth {
    if (_fields.isEmpty) {
      return 0;
    }
    final sum = _fields.fold<int>(0, (value, field) => value + field.health);
    return (sum / _fields.length).round();
  }

  Future<String> _ensureFarm(Map<String, dynamic>? location) async {
    if (_farms.isEmpty) {
      final response = await _apiClient.post(
        '/api/farms',
        auth: true,
        body: {'name': 'Main Farm', 'location': ?location},
      );
      final farm =
          (response['data'] as Map<String, dynamic>)['farm']
              as Map<String, dynamic>;
      _farms = [farm];
      return farm['id']?.toString() ?? '';
    }
    return _farms.first['id']?.toString() ?? '';
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
