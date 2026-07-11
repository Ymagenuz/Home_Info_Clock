import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/app_config.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/services/http_json_client.dart';
import 'package:home_info_clock/services/uapi_weather_source.dart';

class FakeJsonHttpClient extends JsonHttpClient {
  FakeJsonHttpClient({this.onGet, this.onPost});

  final Future<Map<String, dynamic>> Function(
    Uri uri,
    Map<String, String> headers,
  )?
  onGet;
  final Future<Map<String, dynamic>> Function(
    Uri uri,
    Map<String, Object?> body,
    Map<String, String> headers,
  )?
  onPost;

  @override
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String> headers = const {},
  }) {
    return onGet!(uri, headers);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    Uri uri,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
  }) {
    return onPost!(uri, body, headers);
  }
}

void main() {
  test(
    'UapiWeatherSource retries city candidates and parses forecast',
    () async {
      final requestedCities = <String>[];
      final client = FakeJsonHttpClient(
        onGet: (uri, headers) async {
          requestedCities.add(uri.queryParameters['city']!);
          if (requestedCities.length == 1) {
            throw StateError('first city missed');
          }

          return <String, dynamic>{
            'city': '\u4e0a\u6d77',
            'weather': '\u5c0f\u96e8',
            'temperature': 27.6,
            'humidity': '82',
            'wind_power': '3\u7ea7',
            'wind_direction': '\u4e1c\u98ce',
            'report_time': '09:00',
            'forecast': [
              {
                'date': '2026-07-07',
                'weather_day': '\u5c0f\u96e8',
                'temp_max': '29',
                'temp_min': '25',
                'pop': '80',
                'uv_index': '4',
                'wind_scale_day': '4\u7ea7',
                'wind_dir_day': '\u4e1c\u5357\u98ce',
              },
              {
                'date': '2026-07-08',
                'weather_day': '\u591a\u4e91',
                'temp_max': '31',
                'temp_min': '26',
                'precip': 0,
                'uv_index': '6',
                'wind_scale_day': '\u5fae\u98ce',
                'wind_dir_day': '\u897f\u5357\u98ce',
              },
            ],
            'life_indices': {
              'clothing': {'advice': '\u77ed\u8896\u5373\u53ef'},
              'umbrella': {'advice': '\u8bb0\u5f97\u5e26\u4f1e'},
              'travel': {'advice': '\u51fa\u95e8\u6162\u884c'},
              'exercise': {'advice': '\u5ba4\u5185\u8fd0\u52a8'},
              'sunscreen': {'advice': '\u4e2d\u5348\u9632\u6652'},
            },
          };
        },
      );
      final source = UapiWeatherSource(
        client: client,
        config: const AppConfig(uapiToken: ' token '),
      );

      final result = await source.fetch(
        const WeatherRequest(
          latitude: 31.23,
          longitude: 121.47,
          locationLabel: '\u4e0a\u6d77 \u6d66\u4e1c\u65b0\u533a',
        ),
      );

      expect(requestedCities, ['\u6d66\u4e1c\u65b0\u533a', '\u4e0a\u6d77']);
      expect(result.locationLabel, '\u4e0a\u6d77');
      expect(result.currentCode, 61);
      expect(result.currentTemp, 28);
      expect(result.windKmh, 20);
      expect(result.sourceLabel, 'UAPI\u9884\u62a5');
      expect(result.forecastAvailable, isTrue);
      expect(result.days, hasLength(2));
      expect(result.days.first.precipitation, 80);
      expect(result.days.first.windKmh, 26);
      expect(result.days.first.clothingTip, '\u77ed\u8896\u5373\u53ef');
      expect(result.days.first.umbrellaTip, '\u8bb0\u5f97\u5e26\u4f1e');
      expect(result.days.first.travelTip, '\u51fa\u95e8\u6162\u884c');
      expect(result.days.first.sportTip, '\u5ba4\u5185\u8fd0\u52a8');
      expect(result.days.first.sunProtectionTip, '\u4e2d\u5348\u9632\u6652');
      expect(result.days[1].precipitation, 0);
      expect(result.days[1].windKmh, 5);
    },
  );

  test(
    'UapiWeatherSource builds local fallback days when forecast is missing',
    () async {
      final client = FakeJsonHttpClient(
        onGet: (uri, headers) async {
          return <String, dynamic>{
            'city': '\u4e0a\u6d77',
            'weather': '\u9634',
            'temperature': 21,
            'humidity': '88',
            'wind_power': '\u5fae\u98ce',
            'wind_direction': '\u4e1c\u5317\u98ce',
            'report_time': '09:20',
          };
        },
      );
      final source = UapiWeatherSource(
        client: client,
        config: const AppConfig(),
      );

      final result = await source.fetch(
        const WeatherRequest(
          latitude: 31.23,
          longitude: 121.47,
          locationLabel: '\u4e0a\u6d77',
        ),
      );

      expect(result.sourceLabel, 'UAPI\u5b9e\u65f6');
      expect(result.forecastAvailable, isFalse);
      expect(result.days, hasLength(4));
      expect(result.days.first.description, '\u9634');
      expect(result.days[1].description, '\u6682\u65e0\u9884\u62a5');
      expect(
        result.days.first.umbrellaTip,
        '\u6e7f\u5ea6\u8f83\u9ad8\uff0c\u7559\u610f\u77ed\u65f6\u964d\u6c34\u3002',
      );
      expect(
        result.days.first.travelTip,
        '\u6e7f\u5ea6\u9ad8\uff0c\u7559\u610f\u8def\u9762\u6e7f\u6ed1\u3002',
      );
    },
  );

  test('UapiWeatherSource treats an empty forecast as realtime-only', () async {
    final client = FakeJsonHttpClient(
      onGet: (uri, headers) async {
        return <String, dynamic>{
          'city': '\u4e0a\u6d77',
          'weather': '\u9634',
          'temperature': 21,
          'humidity': '88',
          'wind_power': '\u5fae\u98ce',
          'wind_direction': '\u4e1c\u5317\u98ce',
          'report_time': '09:20',
          'forecast': <dynamic>[],
        };
      },
    );
    final source = UapiWeatherSource(client: client, config: const AppConfig());

    final result = await source.fetch(
      const WeatherRequest(
        latitude: 31.23,
        longitude: 121.47,
        locationLabel: '\u4e0a\u6d77',
      ),
    );

    expect(result.sourceLabel, 'UAPI\u5b9e\u65f6');
    expect(result.forecastAvailable, isFalse);
    expect(result.days, hasLength(4));
    expect(result.days.first.description, '\u9634');
    expect(result.days[1].description, '\u6682\u65e0\u9884\u62a5');
  });

  test(
    'UapiWeatherSource rejects Chinese coordinate placeholders before HTTP',
    () async {
      for (final label in const [
        '\u4f4d\u7f6e 31.23,121.47',
        ' \u4f4d\u7f6e\uff1a (31.23\uff0c 121.47) ',
      ]) {
        var calls = 0;
        final client = FakeJsonHttpClient(
          onGet: (uri, headers) async {
            calls += 1;
            return <String, dynamic>{
              'city': '\u4e0a\u6d77',
              'weather': '\u9634',
              'temperature': 21,
            };
          },
        );
        final source = UapiWeatherSource(
          client: client,
          config: const AppConfig(),
        );

        await expectLater(
          source.fetch(
            WeatherRequest(
              latitude: 31.23,
              longitude: 121.47,
              locationLabel: label,
            ),
          ),
          throwsA(isA<StateError>()),
        );
        expect(calls, 0, reason: 'placeholder was $label');
      }
    },
  );

  test(
    'UapiWeatherSource rejects English coordinate placeholders before HTTP',
    () async {
      for (final label in const [
        'Location 31.23,121.47',
        ' lOcAtIoN: (31.23, 121.47). ',
      ]) {
        var calls = 0;
        final client = FakeJsonHttpClient(
          onGet: (uri, headers) async {
            calls += 1;
            return <String, dynamic>{
              'city': '\u4e0a\u6d77',
              'weather': '\u9634',
              'temperature': 21,
            };
          },
        );
        final source = UapiWeatherSource(
          client: client,
          config: const AppConfig(),
        );

        await expectLater(
          source.fetch(
            WeatherRequest(
              latitude: 31.23,
              longitude: 121.47,
              locationLabel: label,
            ),
          ),
          throwsA(isA<StateError>()),
        );
        expect(calls, 0, reason: 'placeholder was $label');
      }
    },
  );
}
