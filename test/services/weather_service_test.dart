import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/services/http_json_client.dart';
import 'package:home_info_clock/services/weather_service.dart';
import 'package:home_info_clock/services/weather_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeWeatherSource implements WeatherSource {
  FakeWeatherSource(this.name, this.result);

  final String name;
  final Object result;
  bool called = false;

  @override
  Future<WeatherSnapshot> fetch(WeatherRequest request) async {
    called = true;
    if (result is Exception) {
      throw result as Exception;
    }
    return result as WeatherSnapshot;
  }
}

class HttpWeatherSource implements WeatherSource {
  HttpWeatherSource(this.client);

  final JsonHttpClient client;

  @override
  Future<WeatherSnapshot> fetch(WeatherRequest request) async {
    await client.getJson(Uri.parse('https://example.test/weather'));
    throw StateError('unreachable');
  }
}

WeatherSnapshot snapshot(
  String source, {
  bool forecast = true,
  int dayCount = 2,
  DateTime? updatedAt,
  int currentTemp = 30,
  int apparentTemp = 32,
  int humidity = 70,
  int windKmh = 12,
  int currentCode = 2,
  String currentDescription = '\u591a\u4e91',
  String reportTimeLabel = '09:00',
  List<WeatherDay>? days,
}) {
  return WeatherSnapshot(
    locationLabel: '\u4e0a\u6d77',
    updatedAt: updatedAt ?? DateTime(2026, 7, 7, 9),
    currentTemp: currentTemp,
    apparentTemp: apparentTemp,
    humidity: humidity,
    windKmh: windKmh,
    currentCode: currentCode,
    currentDescription: currentDescription,
    sourceLabel: source,
    reportTimeLabel: reportTimeLabel,
    forecastAvailable: forecast,
    days:
        days ??
        List.generate(
          dayCount,
          (index) => WeatherDay(
            date: '2026-07-0${index + 7}',
            code: 2,
            description: '\u591a\u4e91',
            high: 32,
            low: 26,
          ),
        ),
  );
}

List<WeatherDay> forecastDays() {
  return const [
    WeatherDay(
      date: '2026-07-07',
      code: 3,
      description: '\u9634',
      high: 33,
      low: 27,
    ),
    WeatherDay(
      date: '2026-07-08',
      code: 61,
      description: '\u96e8',
      high: 31,
      low: 25,
    ),
  ];
}

void main() {
  const request = WeatherRequest(
    latitude: 31.2,
    longitude: 121.5,
    locationLabel: '\u4e0a\u6d77',
  );

  test('WeatherService uses primary when it has forecast data', () async {
    final uapi = FakeWeatherSource('uapi', snapshot('UAPI\u9884\u62a5'));
    final openMeteo = FakeWeatherSource('open', snapshot('Open-Meteo'));
    final service = WeatherService(primary: uapi, fallback: openMeteo);

    final result = await service.fetchWeather(request);

    expect(result.sourceLabel, 'UAPI\u9884\u62a5');
    expect(openMeteo.called, isFalse);
  });

  test(
    'WeatherService fills local tips without replacing source advice',
    () async {
      final days = const [
        WeatherDay(
          date: '2026-07-07',
          code: 2,
          description: '\u591a\u4e91',
          high: 18,
          low: 11,
        ),
        WeatherDay(
          date: '2026-07-08',
          code: 61,
          description: '\u96e8',
          high: 12,
          low: 6,
          precipitation: 80,
          windKmh: 35,
          clothingTip: 'Source clothing',
        ),
      ];
      final primary = FakeWeatherSource(
        'primary',
        snapshot('Source', days: days),
      );
      final service = WeatherService(
        primary: primary,
        fallback: FakeWeatherSource('fallback', snapshot('Fallback')),
      );

      final result = await service.fetchWeather(request);

      expect(result.tomorrow?.clothingTip, 'Source clothing');
      expect(result.tomorrow?.umbrellaTip, isNotEmpty);
      expect(result.tomorrow?.travelTip, isNotEmpty);
    },
  );

  test(
    'WeatherService merges primary realtime with fallback forecast',
    () async {
      final realtimeAt = DateTime(2026, 7, 7, 9, 20);
      final days = forecastDays();
      final uapi = FakeWeatherSource(
        'uapi',
        snapshot(
          'UAPI\u5b9e\u65f6',
          forecast: false,
          dayCount: 1,
          updatedAt: realtimeAt,
          currentTemp: 28,
          apparentTemp: 28,
          humidity: 88,
          windKmh: 5,
          currentCode: 61,
          currentDescription: '\u5c0f\u96e8',
          reportTimeLabel: '09:20',
        ),
      );
      final openMeteo = FakeWeatherSource(
        'open',
        snapshot(
          '\u9884\u62a5',
          currentTemp: 31,
          apparentTemp: 31,
          humidity: 65,
          windKmh: 18,
          currentCode: 3,
          currentDescription: '\u9634',
          days: days,
        ),
      );
      final service = WeatherService(primary: uapi, fallback: openMeteo);

      final result = await service.fetchWeather(request);

      expect(result.locationLabel, '\u4e0a\u6d77');
      expect(result.updatedAt, realtimeAt);
      expect(result.currentTemp, 28);
      expect(result.apparentTemp, 28);
      expect(result.humidity, 88);
      expect(result.windKmh, 5);
      expect(result.currentCode, 61);
      expect(result.currentDescription, '\u5c0f\u96e8');
      expect(result.sourceLabel, '\u5b9e\u65f6+\u9884\u62a5');
      expect(result.reportTimeLabel, '09:20');
      expect(result.forecastAvailable, isTrue);
      expect(result.days.map((day) => day.date), days.map((day) => day.date));
      expect(result.days[1].description, days[1].description);
      expect(openMeteo.called, isTrue);
    },
  );

  test(
    'WeatherService tries secondary fallback before realtime-only fallback',
    () async {
      final days = forecastDays();
      final uapi = FakeWeatherSource(
        'uapi',
        snapshot(
          'UAPI\u5b9e\u65f6',
          forecast: false,
          dayCount: 1,
          currentTemp: 28,
          currentDescription: '\u5c0f\u96e8',
        ),
      );
      final openMeteo = FakeWeatherSource('open', StateError('open failed'));
      final qweather = FakeWeatherSource(
        'qweather',
        snapshot('\u548c\u98ce\u9884\u62a5', days: days),
      );
      final service = WeatherService(
        primary: uapi,
        fallback: openMeteo,
        secondaryFallback: qweather,
      );

      final result = await service.fetchWeather(request);

      expect(result.sourceLabel, '\u5b9e\u65f6+\u9884\u62a5');
      expect(result.currentTemp, 28);
      expect(result.currentDescription, '\u5c0f\u96e8');
      expect(result.days.map((day) => day.date), days.map((day) => day.date));
      expect(result.days[1].description, days[1].description);
      expect(openMeteo.called, isTrue);
      expect(qweather.called, isTrue);
    },
  );

  test('WeatherService falls back after a primary HTTP timeout', () async {
    final pending = Completer<http.Response>();
    final primary = HttpWeatherSource(
      JsonHttpClient(
        client: MockClient((_) => pending.future),
        timeout: const Duration(milliseconds: 5),
      ),
    );
    final fallback = FakeWeatherSource('fallback', snapshot('Open-Meteo'));
    final service = WeatherService(primary: primary, fallback: fallback);

    final result = await service.fetchWeather(request);

    expect(result.sourceLabel, 'Open-Meteo');
    expect(fallback.called, isTrue);
  });
}
