import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/services/http_json_client.dart';
import 'package:home_info_clock/services/open_meteo_weather_source.dart';

class FakeJsonHttpClient extends JsonHttpClient {
  FakeJsonHttpClient({required this.onGet});

  final Future<Map<String, dynamic>> Function(
    Uri uri,
    Map<String, String> headers,
  )
  onGet;

  @override
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String> headers = const {},
  }) {
    return onGet(uri, headers);
  }
}

void main() {
  test(
    'OpenMeteoWeatherSource parses current and daily forecast fields',
    () async {
      Uri? requestedUri;
      final client = FakeJsonHttpClient(
        onGet: (uri, headers) async {
          requestedUri = uri;
          return <String, dynamic>{
            'current': {
              'temperature_2m': 30.6,
              'relative_humidity_2m': 74,
              'weather_code': 3,
              'wind_speed_10m': 12.4,
            },
            'daily': {
              'time': ['2026-07-07', '2026-07-08'],
              'weather_code': [3, 61],
              'temperature_2m_max': [33.2, 31.4],
              'temperature_2m_min': [27.5, 25.2],
              'precipitation_probability_max': [20, 80],
              'wind_speed_10m_max': [16.4, 21.6],
              'uv_index_max': [7.1, 3.2],
            },
          };
        },
      );
      final source = OpenMeteoWeatherSource(client: client);

      final result = await source.fetch(
        const WeatherRequest(
          latitude: 31.23,
          longitude: 121.47,
          locationLabel: '\u4e0a\u6d77',
        ),
      );

      expect(requestedUri?.host, 'api.open-meteo.com');
      expect(requestedUri?.queryParameters['forecast_days'], '15');
      expect(result.sourceLabel, '\u9884\u62a5');
      expect(result.currentTemp, 31);
      expect(result.apparentTemp, 31);
      expect(result.humidity, 74);
      expect(result.windKmh, 12);
      expect(result.currentDescription, '\u9634');
      expect(result.days, hasLength(2));
      expect(result.days.first.icon, '\u2601');
      expect(result.days[1].description, '\u96e8');
      expect(result.days[1].precipitation, 80);
      expect(result.days[1].windKmh, 22);
      expect(result.days[1].uv, 3);
    },
  );
}
