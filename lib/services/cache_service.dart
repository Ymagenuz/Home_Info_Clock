import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/timer_state.dart';
import '../models/weather.dart';

class CacheService {
  const CacheService(this.preferences);

  static const _weatherKey = 'weather_json';
  static const _timerKey = 'timer_json';

  final SharedPreferences preferences;

  Future<void> saveWeather(WeatherSnapshot snapshot) {
    return preferences.setString(_weatherKey, jsonEncode(snapshot.toJson()));
  }

  WeatherSnapshot? loadWeather() {
    final raw = preferences.getString(_weatherKey);
    if (raw == null || raw.isEmpty) return null;
    return WeatherSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveTimer(TimerState state) {
    return preferences.setString(_timerKey, jsonEncode(state.toJson()));
  }

  TimerState loadTimer() {
    final raw = preferences.getString(_timerKey);
    if (raw == null || raw.isEmpty) return const TimerState();
    return TimerState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
