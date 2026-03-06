import 'package:flutter/material.dart';

/// Weather data for a single day
class DayWeather {
  final String dayEn;
  final String dayAr;
  final int temp;
  final String conditionEn;
  final String conditionAr;
  final IconData icon;

  const DayWeather({
    required this.dayEn,
    required this.dayAr,
    required this.temp,
    required this.conditionEn,
    required this.conditionAr,
    required this.icon,
  });
}

/// Provider that manages weather data.
/// Ready to connect to backend — see TODO for Weather API integration.
class WeatherProvider extends ChangeNotifier {
  // Current weather
  int _temperature = 28;
  int _humidity = 65;
  int _wind = 12;
  String _conditionEn = 'Partly Cloudy';
  String _conditionAr = 'غائم جزئياً';

  int get temperature => _temperature;
  int get humidity => _humidity;
  int get wind => _wind;
  String conditionEn(bool isRTL) => isRTL ? _conditionAr : _conditionEn;

  // 7-day forecast
  final List<DayWeather> _forecast = const [
    DayWeather(dayEn: 'Mon', dayAr: 'الاثنين', temp: 24, conditionEn: 'Sunny', conditionAr: 'مشمس', icon: Icons.wb_sunny_rounded),
    DayWeather(dayEn: 'Tue', dayAr: 'الثلاثاء', temp: 26, conditionEn: 'Partly Cloudy', conditionAr: 'غائم جزئياً', icon: Icons.cloud_rounded),
    DayWeather(dayEn: 'Wed', dayAr: 'الأربعاء', temp: 28, conditionEn: 'Cloudy', conditionAr: 'غائم', icon: Icons.cloud_queue_rounded),
    DayWeather(dayEn: 'Thu', dayAr: 'الخميس', temp: 30, conditionEn: 'Sunny', conditionAr: 'مشمس', icon: Icons.wb_sunny_rounded),
    DayWeather(dayEn: 'Fri', dayAr: 'الجمعة', temp: 29, conditionEn: 'Rainy', conditionAr: 'ممطر', icon: Icons.water_drop_rounded),
    DayWeather(dayEn: 'Sat', dayAr: 'السبت', temp: 27, conditionEn: 'Partly Cloudy', conditionAr: 'غائم جزئياً', icon: Icons.cloud_rounded),
    DayWeather(dayEn: 'Sun', dayAr: 'الأحد', temp: 25, conditionEn: 'Sunny', conditionAr: 'مشمس', icon: Icons.wb_sunny_rounded),
  ];

  List<DayWeather> get forecast => _forecast;

  /// TODO: Replace with API call to Weather API
  void refreshWeather() {
    // Simulated refresh
    _temperature = 28;
    _humidity = 65;
    _wind = 12;
    _conditionEn = 'Partly Cloudy';
    _conditionAr = 'غائم جزئياً';
    notifyListeners();
  }
}
