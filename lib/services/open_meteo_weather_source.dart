import '../models/weather.dart';
import 'http_json_client.dart';
import 'weather_service_support.dart';
import 'weather_source.dart';

class OpenMeteoWeatherSource implements WeatherSource {
  const OpenMeteoWeatherSource({required this.client});

  final JsonHttpClient client;

  @override
  Future<WeatherSnapshot> fetch(WeatherRequest request) async {
    final root = await client.getJson(
      Uri.https('api.open-meteo.com', '/v1/forecast', <String, String>{
        'latitude': request.latitude.toStringAsFixed(4),
        'longitude': request.longitude.toStringAsFixed(4),
        'current':
            'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max,uv_index_max',
        'forecast_days': '15',
        'timezone': 'auto',
      }),
    );

    final current = asMap(root['current'], 'current');
    final daily = asMap(root['daily'], 'daily');
    final now = DateTime.now();

    return WeatherSnapshot(
      locationLabel: request.locationLabel,
      updatedAt: now,
      currentTemp: roundNum(current['temperature_2m']),
      apparentTemp: roundNum(current['temperature_2m']),
      humidity: roundNum(current['relative_humidity_2m']),
      windKmh: roundNum(current['wind_speed_10m']),
      currentCode: intValue(current['weather_code'], 3),
      currentDescription: weatherDescription(
        intValue(current['weather_code'], 3),
      ),
      sourceLabel: '\u9884\u62a5',
      reportTimeLabel: formatHm(now),
      forecastAvailable: true,
      days: _parseDailyForecast(daily),
    );
  }

  List<WeatherDay> _parseDailyForecast(Map<String, dynamic> daily) {
    final dates = asList(daily['time'], 'daily.time');
    final codes = asList(daily['weather_code'], 'daily.weather_code');
    final highs = asList(
      daily['temperature_2m_max'],
      'daily.temperature_2m_max',
    );
    final lows = asList(
      daily['temperature_2m_min'],
      'daily.temperature_2m_min',
    );
    final rain = daily['precipitation_probability_max'] as List<dynamic>?;
    final wind = daily['wind_speed_10m_max'] as List<dynamic>?;
    final uv = daily['uv_index_max'] as List<dynamic>?;

    return List<WeatherDay>.generate(dates.length, (index) {
      final code = intValue(index < codes.length ? codes[index] : null, 3);
      return WeatherDay(
        date: stringValue(index < dates.length ? dates[index] : null),
        code: code,
        description: weatherDescription(code),
        icon: weatherIcon(code),
        high: roundNum(index < highs.length ? highs[index] : null),
        low: roundNum(index < lows.length ? lows[index] : null),
        precipitation: intValue(
          index < (rain?.length ?? 0) ? rain![index] : null,
          0,
        ),
        windKmh: roundNum(index < (wind?.length ?? 0) ? wind![index] : null),
        uv: roundNum(index < (uv?.length ?? 0) ? uv![index] : null),
      );
    });
  }
}
