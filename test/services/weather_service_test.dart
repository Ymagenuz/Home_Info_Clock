import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/app_config.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/services/http_json_client.dart';
import 'package:home_info_clock/services/uapi_weather_source.dart';
import 'package:home_info_clock/services/weather_service.dart';
import 'package:home_info_clock/services/weather_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeWeatherSource implements WeatherSource {
  FakeWeatherSource(this.name, this.result);

  final String name;
  final Object result;
  int callCount = 0;

  @override
  Future<WeatherSnapshot> fetch(WeatherRequest request) async {
    callCount += 1;
    if (result case final WeatherSnapshot snapshot) {
      return snapshot;
    }
    throw result;
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

class StubJsonHttpClient extends JsonHttpClient {
  StubJsonHttpClient(this.response);

  final Map<String, dynamic> response;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    calls += 1;
    return response;
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
    expect(openMeteo.callCount, 0);
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
      expect(openMeteo.callCount, 1);
    },
  );

  test(
    'WeatherService merges UAPI realtime from an empty forecast with fallback days',
    () async {
      final uapiClient = StubJsonHttpClient(<String, dynamic>{
        'city': '\u4e0a\u6d77',
        'weather': '\u5c0f\u96e8',
        'temperature': 28,
        'humidity': '88',
        'wind_power': '\u5fae\u98ce',
        'wind_direction': '\u4e1c\u98ce',
        'report_time': '09:20',
        'forecast': <dynamic>[],
      });
      final fallbackDays = forecastDays();
      final openMeteo = FakeWeatherSource(
        'open',
        snapshot('Open-Meteo', days: fallbackDays),
      );
      final service = WeatherService(
        primary: UapiWeatherSource(
          client: uapiClient,
          config: const AppConfig(),
        ),
        fallback: openMeteo,
      );

      final result = await service.fetchWeather(request);

      expect(uapiClient.calls, 1);
      expect(openMeteo.callCount, 1);
      expect(result.currentTemp, 28);
      expect(result.humidity, 88);
      expect(result.currentDescription, '\u5c0f\u96e8');
      expect(result.reportTimeLabel, '09:20');
      expect(result.sourceLabel, '\u5b9e\u65f6+\u9884\u62a5');
      expect(result.forecastAvailable, isTrue);
      expect(
        result.days.map((day) => day.date),
        fallbackDays.map((day) => day.date),
      );
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
      expect(openMeteo.callCount, 1);
      expect(qweather.callCount, 1);
    },
  );

  test('WeatherService calls a throwing fallback at most once', () async {
    final primaryFailure = Exception('primary failed');
    final primary = FakeWeatherSource('primary', primaryFailure);
    final fallback = FakeWeatherSource(
      'fallback',
      Exception('fallback failed'),
    );
    final service = WeatherService(primary: primary, fallback: fallback);

    Object? thrown;
    try {
      await service.fetchWeather(request);
    } catch (error) {
      thrown = error;
    }

    expect(thrown, same(primaryFailure));
    expect(primary.callCount, 1);
    expect(fallback.callCount, 1);
  });

  test(
    'WeatherService does not recall a fallback with empty forecast days',
    () async {
      final primary = FakeWeatherSource('primary', Exception('primary failed'));
      final emptyFallback = FakeWeatherSource(
        'fallback',
        snapshot('Empty fallback', forecast: true, dayCount: 0),
      );
      final service = WeatherService(primary: primary, fallback: emptyFallback);

      final result = await service.fetchWeather(request);

      expect(result.sourceLabel, 'Empty fallback');
      expect(result.days, isEmpty);
      expect(primary.callCount, 1);
      expect(emptyFallback.callCount, 1);
    },
  );

  test(
    'WeatherService retains primary realtime after unusable and failed fallbacks',
    () async {
      final primaryRealtime = FakeWeatherSource(
        'primary',
        snapshot(
          'Primary realtime',
          forecast: false,
          dayCount: 1,
          currentTemp: 28,
          currentDescription: '\u5c0f\u96e8',
        ),
      );
      final emptyFallback = FakeWeatherSource(
        'fallback',
        snapshot('Empty fallback', forecast: true, dayCount: 0),
      );
      final secondary = FakeWeatherSource(
        'secondary',
        Exception('secondary failed'),
      );
      final service = WeatherService(
        primary: primaryRealtime,
        fallback: emptyFallback,
        secondaryFallback: secondary,
      );

      final result = await service.fetchWeather(request);

      expect(result.sourceLabel, 'Primary realtime');
      expect(result.currentTemp, 28);
      expect(result.currentDescription, '\u5c0f\u96e8');
      expect(result.forecastAvailable, isFalse);
      expect(primaryRealtime.callCount, 1);
      expect(emptyFallback.callCount, 1);
      expect(secondary.callCount, 1);
    },
  );

  test(
    'WeatherService rethrows the original primary exception after all sources fail',
    () async {
      final primaryFailure = Exception('original primary failure');
      final primary = FakeWeatherSource('primary', primaryFailure);
      final fallback = FakeWeatherSource(
        'fallback',
        Exception('fallback failure'),
      );
      final secondary = FakeWeatherSource(
        'secondary',
        Exception('secondary failure'),
      );
      final service = WeatherService(
        primary: primary,
        fallback: fallback,
        secondaryFallback: secondary,
      );

      Object? thrown;
      try {
        await service.fetchWeather(request);
      } catch (error) {
        thrown = error;
      }

      expect(thrown, same(primaryFailure));
      expect(primary.callCount, 1);
      expect(fallback.callCount, 1);
      expect(secondary.callCount, 1);
    },
  );

  test(
    'WeatherService keeps advertised-empty realtime and uses a later forecast',
    () async {
      final advertisedEmpty = FakeWeatherSource(
        'primary',
        snapshot(
          'Advertised empty',
          forecast: true,
          dayCount: 0,
          currentTemp: 28,
          currentDescription: '\u5c0f\u96e8',
        ),
      );
      final days = forecastDays();
      final fallback = FakeWeatherSource(
        'fallback',
        snapshot('Fallback forecast', days: days),
      );
      final service = WeatherService(
        primary: advertisedEmpty,
        fallback: fallback,
      );

      final result = await service.fetchWeather(request);

      expect(result.sourceLabel, '\u5b9e\u65f6+\u9884\u62a5');
      expect(result.currentTemp, 28);
      expect(result.currentDescription, '\u5c0f\u96e8');
      expect(result.days.map((day) => day.date), days.map((day) => day.date));
      expect(advertisedEmpty.callCount, 1);
      expect(fallback.callCount, 1);
    },
  );

  test(
    'WeatherService skips unadvertised placeholder days for a later forecast',
    () async {
      final primaryRealtime = FakeWeatherSource(
        'primary',
        snapshot(
          'Primary realtime',
          forecast: false,
          dayCount: 1,
          currentTemp: 28,
        ),
      );
      final placeholderFallback = FakeWeatherSource(
        'fallback',
        snapshot('Placeholder days', forecast: false, dayCount: 4),
      );
      final days = forecastDays();
      final secondaryForecast = FakeWeatherSource(
        'secondary',
        snapshot('Secondary forecast', days: days),
      );
      final service = WeatherService(
        primary: primaryRealtime,
        fallback: placeholderFallback,
        secondaryFallback: secondaryForecast,
      );

      final result = await service.fetchWeather(request);

      expect(result.sourceLabel, '\u5b9e\u65f6+\u9884\u62a5');
      expect(result.currentTemp, 28);
      expect(result.days.map((day) => day.date), days.map((day) => day.date));
      expect(primaryRealtime.callCount, 1);
      expect(placeholderFallback.callCount, 1);
      expect(secondaryForecast.callCount, 1);
    },
  );

  test(
    'WeatherService accepts an advertised forecast with one non-empty day',
    () async {
      final primary = FakeWeatherSource(
        'primary',
        snapshot('One-day forecast', forecast: true, dayCount: 1),
      );
      final fallback = FakeWeatherSource(
        'fallback',
        snapshot('Fallback forecast'),
      );
      final service = WeatherService(primary: primary, fallback: fallback);

      final result = await service.fetchWeather(request);

      expect(result.sourceLabel, 'One-day forecast');
      expect(result.days, hasLength(1));
      expect(primary.callCount, 1);
      expect(fallback.callCount, 0);
    },
  );

  for (final placeholder in const {
    'Chinese': ' \u4f4d\u7f6e\uff1a (31.2\uff0c 121.5) ',
    'English': ' LOCATION: (31.2, 121.5). ',
  }.entries) {
    test(
      'WeatherService reaches coordinate fallback for ${placeholder.key} placeholder',
      () async {
        final uapiClient = StubJsonHttpClient(<String, dynamic>{
          'city': '\u4e0a\u6d77',
          'weather': '\u9634',
          'temperature': 21,
          'forecast': <dynamic>[
            <String, dynamic>{
              'date': '2026-07-07',
              'weather_day': '\u9634',
              'temp_max': 25,
              'temp_min': 19,
            },
          ],
        });
        final coordinateFallback = FakeWeatherSource(
          'fallback',
          snapshot('Open-Meteo'),
        );
        final service = WeatherService(
          primary: UapiWeatherSource(
            client: uapiClient,
            config: const AppConfig(),
          ),
          fallback: coordinateFallback,
        );

        final result = await service.fetchWeather(
          WeatherRequest(
            latitude: 31.2,
            longitude: 121.5,
            locationLabel: placeholder.value,
          ),
        );

        expect(uapiClient.calls, 0);
        expect(coordinateFallback.callCount, 1);
        expect(result.sourceLabel, 'Open-Meteo');
      },
    );
  }

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
    expect(fallback.callCount, 1);
  });
}
