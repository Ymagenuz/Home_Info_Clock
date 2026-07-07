import '../models/weather.dart';
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
    try {
      final snapshot = await primary.fetch(request);
      if (snapshot.forecastAvailable && snapshot.days.length > 1) {
        return snapshot;
      }
    } catch (_) {
      // Fall through to the next source.
    }

    try {
      final snapshot = await fallback.fetch(request);
      if (snapshot.days.isNotEmpty) {
        return snapshot;
      }
    } catch (_) {
      // Fall through to optional source.
    }

    final last = secondaryFallback;
    if (last != null) {
      return last.fetch(request);
    }
    return fallback.fetch(request);
  }
}
