import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/manual_location.dart';
import '../models/timer_state.dart';
import '../models/weather.dart';

class CacheService {
  const CacheService(this.preferences);

  static const _weatherKey = 'weather_json';
  static const _timerKey = 'timer_json';
  static const _locationKey = 'manual_location_json';

  final SharedPreferences preferences;

  Future<void> saveWeather(WeatherSnapshot snapshot) {
    return preferences.setString(_weatherKey, jsonEncode(snapshot.toJson()));
  }

  WeatherSnapshot? loadWeather() {
    final raw = preferences.getString(_weatherKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _clearKey(_weatherKey);
        return null;
      }
      return WeatherSnapshot.fromJson(decoded);
    } on FormatException {
      _clearKey(_weatherKey);
      return null;
    } on TypeError {
      _clearKey(_weatherKey);
      return null;
    } on ArgumentError {
      _clearKey(_weatherKey);
      return null;
    }
  }

  Future<void> clearWeather() {
    return preferences.remove(_weatherKey);
  }

  Future<void> saveLocation(ManualLocation location) {
    return preferences.setString(_locationKey, jsonEncode(location.toJson()));
  }

  ManualLocation? loadLocation() {
    final raw = preferences.getString(_locationKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _clearKey(_locationKey);
        return null;
      }
      return ManualLocation.fromJson(decoded);
    } on FormatException {
      _clearKey(_locationKey);
      return null;
    } on TypeError {
      _clearKey(_locationKey);
      return null;
    } on ArgumentError {
      _clearKey(_locationKey);
      return null;
    }
  }

  Future<void> saveTimer(TimerState state) {
    return preferences.setString(_timerKey, jsonEncode(state.toJson()));
  }

  TimerState loadTimer() {
    final raw = preferences.getString(_timerKey);
    if (raw == null || raw.isEmpty) return const TimerState();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _clearKey(_timerKey);
        return const TimerState();
      }
      return TimerState.fromJson(decoded);
    } on FormatException {
      _clearKey(_timerKey);
      return const TimerState();
    } on TypeError {
      _clearKey(_timerKey);
      return const TimerState();
    } on ArgumentError {
      _clearKey(_timerKey);
      return const TimerState();
    }
  }

  void _clearKey(String key) {
    unawaited(preferences.remove(key));
  }
}
