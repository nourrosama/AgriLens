import 'package:flutter/material.dart';

import 'api_client.dart';

class DayWeather {
  const DayWeather({
    required this.dayEn,
    required this.dayAr,
    required this.temp,
    required this.conditionEn,
    required this.conditionAr,
    required this.icon,
  });

  final String dayEn;
  final String dayAr;
  final int temp;
  final String conditionEn;
  final String conditionAr;
  final IconData icon;

  factory DayWeather.fromJson(Map<String, dynamic> json) {
    final condition = json['condition']?.toString() ?? 'Partly Cloudy';
    return DayWeather(
      dayEn: json['day']?.toString() ?? '',
      dayAr: json['day']?.toString() ?? '',
      temp: (json['temperature'] as num?)?.round() ?? 0,
      conditionEn: condition,
      conditionAr: condition,
      icon: _iconFor(condition),
    );
  }

  static IconData _iconFor(String condition) {
    switch (condition.toLowerCase()) {
      case 'sunny':
        return Icons.wb_sunny_rounded;
      case 'cloudy':
        return Icons.cloud_queue_rounded;
      case 'rainy':
        return Icons.water_drop_rounded;
      default:
        return Icons.cloud_rounded;
    }
  }
}

class WeatherProvider extends ChangeNotifier {
  WeatherProvider({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient() {
    refreshWeather();
  }

  final ApiClient _apiClient;
  int _temperature = 0;
  int _humidity = 0;
  int _wind = 0;
  String _condition = 'Partly Cloudy';
  List<DayWeather> _forecast = const [];
  bool _isLoading = false;
  String? _errorMessage;

  int get temperature => _temperature;
  int get humidity => _humidity;
  int get wind => _wind;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String condition(bool isRTL) => _condition;
  List<DayWeather> get forecast => _forecast;

  Future<void> refreshWeather({String? farmId}) async {
    _setLoading(true);
    try {
      final response = await _apiClient.get(
        '/api/weather',
        auth: true,
        query: {if (farmId != null && farmId.isNotEmpty) 'farm_id': farmId},
      );
      final weather =
          (response['data'] as Map<String, dynamic>)['weather']
              as Map<String, dynamic>;
      _temperature = (weather['temperature'] as num?)?.round() ?? 0;
      _humidity = (weather['humidity'] as num?)?.round() ?? 0;
      _wind = (weather['wind_kmh'] as num?)?.round() ?? 0;
      _condition = weather['condition']?.toString() ?? 'Partly Cloudy';
      _forecast =
          ((weather['forecast'] as List<dynamic>? ?? [])
                  .cast<Map<String, dynamic>>())
              .map(DayWeather.fromJson)
              .toList();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
