import '../models/app_config.dart';
import '../models/weather.dart';
import 'http_json_client.dart';
import 'weather_service_support.dart';
import 'weather_source.dart';

class QWeatherWeatherSource implements WeatherSource {
  const QWeatherWeatherSource({required this.client, required this.config});

  final JsonHttpClient client;
  final AppConfig config;

  @override
  Future<WeatherSnapshot> fetch(WeatherRequest request) async {
    final locationParam =
        '${request.longitude.toStringAsFixed(2)},${request.latitude.toStringAsFixed(2)}';
    final basePath = '/v7';
    final headers = _authHeaders();
    final host = config.qweatherApiHost;

    final nowRoot = await _readQWeatherJson(
      Uri.https(host, '$basePath/weather/now', {
        'location': locationParam,
        'lang': 'zh',
        'unit': 'm',
      }),
      headers,
    );
    final dailyRoot = await _readQWeatherJson(
      Uri.https(host, '$basePath/weather/7d', {
        'location': locationParam,
        'lang': 'zh',
        'unit': 'm',
      }),
      headers,
    );
    final indicesRoot = await _readQWeatherJson(
      Uri.https(host, '$basePath/indices/3d', {
        'location': locationParam,
        'type': '1,3,6,16',
        'lang': 'zh',
      }),
      headers,
    );

    final now = asMap(nowRoot['now'], 'now');
    final currentCode = _normalizeQWeatherIcon(stringValue(now['icon'], '999'));

    return WeatherSnapshot(
      locationLabel: request.locationLabel,
      updatedAt: DateTime.now(),
      currentTemp: intValue(now['temp']),
      apparentTemp: intValue(now['feelsLike'], intValue(now['temp'])),
      humidity: intValue(now['humidity']),
      windKmh: intValue(now['windSpeed']),
      currentCode: currentCode,
      currentDescription: stringValue(
        now['text'],
        weatherDescription(currentCode),
      ),
      sourceLabel: '\u548c\u98ce\u9884\u62a5',
      reportTimeLabel: formatHm(DateTime.now()),
      forecastAvailable: true,
      days: _parseDailyForecast(
        asMap(dailyRoot, 'dailyRoot'),
        _parseIndices(asMap(indicesRoot, 'indicesRoot')),
      ),
    );
  }

  Map<String, String> _authHeaders() {
    if (config.hasQWeatherApiKey) {
      return {'X-QW-Api-Key': config.qweatherApiKey.trim()};
    }
    if (config.hasQWeatherJwtConfig) {
      throw UnimplementedError(
        'JWT-authenticated QWeather requests are not implemented',
      );
    }
    throw StateError('weather forecast unavailable');
  }

  Future<Map<String, dynamic>> _readQWeatherJson(
    Uri uri,
    Map<String, String> headers,
  ) async {
    final root = await client.getJson(uri, headers: headers);
    final code = stringValue(root['code']);
    if (code != '200') {
      throw StateError('QWeather request failed: code=$code url=$uri');
    }
    return root;
  }

  List<WeatherDay> _parseDailyForecast(
    Map<String, dynamic> dailyRoot,
    Map<String, Map<String, String>> indicesByDate,
  ) {
    final daily = asList(dailyRoot['daily'], 'daily');
    return daily.map((item) {
      final map = asMap(item, 'daily item');
      final iconDay = stringValue(map['iconDay'], '999');
      final textDay = stringValue(map['textDay']);
      final precipMm = numValue(map['precip']);
      final code = _normalizeQWeatherIcon(iconDay);
      final day = WeatherDay(
        date: stringValue(map['fxDate']),
        code: code,
        description: textDay.isEmpty ? weatherDescription(code) : textDay,
        icon: weatherIcon(code),
        high: intValue(map['tempMax']),
        low: intValue(map['tempMin']),
        precipitation: _estimatePrecipitationProbability(textDay, precipMm),
        uv: intValue(map['uvIndex']),
        windKmh: intValue(map['windSpeedDay']),
      );
      return _applyIndices(day, indicesByDate[day.date]);
    }).toList();
  }

  Map<String, Map<String, String>> _parseIndices(
    Map<String, dynamic> indicesRoot,
  ) {
    final result = <String, Map<String, String>>{};
    final daily = indicesRoot['daily'];
    if (daily is! List) {
      return result;
    }

    for (final item in daily) {
      final map = asMap(item, 'indices item');
      final date = stringValue(map['date']);
      final type = stringValue(map['type']);
      final text = stringValue(map['text']);
      if (date.isEmpty || type.isEmpty || text.isEmpty) {
        continue;
      }
      result.putIfAbsent(date, () => <String, String>{})[type] = text;
    }
    return result;
  }

  WeatherDay _applyIndices(WeatherDay day, Map<String, String>? indices) {
    if (indices == null) {
      return day;
    }
    return day.copyWith(
      sportTip: indices['1'],
      clothingTip: indices['3'],
      travelTip: indices['6'],
      sunProtectionTip: indices['16'],
    );
  }

  int _estimatePrecipitationProbability(String text, num precipMm) {
    if (precipMm >= 10) return 90;
    if (precipMm >= 2) return 70;
    if (precipMm > 0) return 45;
    if (text.contains('\u96e8') || text.contains('\u96ea')) return 55;
    return 0;
  }

  int _normalizeQWeatherIcon(String icon) {
    final code = intValue(icon, 999);
    if (code == 100 || code == 150) return 0;
    if ((code >= 101 && code <= 103) || (code >= 151 && code <= 153)) return 2;
    if (code == 104 || code == 154) return 3;
    if (code >= 300 && code <= 399) return 61;
    if (code >= 400 && code <= 499) return 71;
    if (code >= 500 && code <= 501) return 45;
    if (code >= 502 && code <= 515) return 451;
    if (code >= 200 && code <= 213) return 2;
    if (code == 900) return 0;
    if (code == 901) return 3;
    return 3;
  }
}
