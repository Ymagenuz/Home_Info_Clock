import '../models/weather.dart';
import 'local_weather_advice.dart';
import 'weather_source.dart';

class WeatherService {
  const WeatherService({
    required this.primary,
    required this.fallback,
    this.secondaryFallback,
  });

  final WeatherSource primary;
  final WeatherSource fallback;
  final WeatherSource? secondaryFallback;

  Future<WeatherSnapshot> fetchWeather(WeatherRequest request) async {
    return ensureLocalWeatherAdvice(await _fetchWeather(request));
  }

  Future<WeatherSnapshot> _fetchWeather(WeatherRequest request) async {
    WeatherSnapshot? realtime;
    try {
      final snapshot = await primary.fetch(request);
      if (snapshot.forecastAvailable && snapshot.days.length > 1) {
        return snapshot;
      }
      realtime = snapshot;
    } catch (_) {
      // Fall through to the next source.
    }

    try {
      final snapshot = await fallback.fetch(request);
      if (snapshot.days.isNotEmpty) {
        if (realtime != null) {
          return _mergeRealtimeWithForecast(realtime, snapshot);
        }
        return snapshot;
      }
    } catch (_) {
      // Fall through to optional source.
    }

    final last = secondaryFallback;
    if (last != null) {
      try {
        final snapshot = await last.fetch(request);
        if (realtime != null && snapshot.days.isNotEmpty) {
          return _mergeRealtimeWithForecast(realtime, snapshot);
        }
        return snapshot;
      } catch (_) {
        if (realtime != null) {
          return realtime;
        }
        rethrow;
      }
    }
    if (realtime != null) {
      return realtime;
    }
    return fallback.fetch(request);
  }

  WeatherSnapshot _mergeRealtimeWithForecast(
    WeatherSnapshot realtime,
    WeatherSnapshot forecast,
  ) {
    return forecast.copyWith(
      locationLabel: realtime.locationLabel,
      updatedAt: realtime.updatedAt,
      currentTemp: realtime.currentTemp,
      apparentTemp: realtime.apparentTemp,
      humidity: realtime.humidity,
      windKmh: realtime.windKmh,
      currentCode: realtime.currentCode,
      currentDescription: realtime.currentDescription,
      sourceLabel: '\u5b9e\u65f6+\u9884\u62a5',
      reportTimeLabel: realtime.reportTimeLabel,
      forecastAvailable: true,
    );
  }
}
