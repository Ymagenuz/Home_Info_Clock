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
    Object? firstError;
    StackTrace? firstStackTrace;
    final sources = [primary, fallback, ?secondaryFallback];

    for (final source in sources) {
      try {
        final snapshot = await source.fetch(request);
        if (_hasUsableForecast(snapshot)) {
          return realtime == null
              ? snapshot
              : _mergeRealtimeWithForecast(realtime, snapshot);
        }
        realtime ??= snapshot;
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    if (realtime != null) {
      return realtime;
    }
    Error.throwWithStackTrace(firstError!, firstStackTrace!);
  }

  bool _hasUsableForecast(WeatherSnapshot snapshot) =>
      snapshot.forecastAvailable && snapshot.days.isNotEmpty;

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
