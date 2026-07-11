import '../models/app_config.dart';
import '../models/weather.dart';
import 'http_json_client.dart';
import 'weather_service_support.dart';
import 'weather_source.dart';

class UapiWeatherSource implements WeatherSource {
  const UapiWeatherSource({required this.client, required this.config});

  static final RegExp _coordinatePlaceholderLabel = RegExp(
    r'^\s*(?:'
    '\u4f4d\u7f6e'
    r'|location)'
    r'[\s:;,\.\-\uFF1A\uFF1B\uFF0C\u2013\u2014]*'
    r'(?:[\(\[\{\uFF08]\s*)?'
    r'[+-]?(?:\d+(?:\.\d+)?|\.\d+)'
    r'\s*[,\uFF0C]\s*'
    r'[+-]?(?:\d+(?:\.\d+)?|\.\d+)'
    r'(?:\s*[\)\]\}\uFF09])?'
    r'\s*[.!\u3002]?\s*$',
    caseSensitive: false,
  );

  final JsonHttpClient client;
  final AppConfig config;

  @override
  Future<WeatherSnapshot> fetch(WeatherRequest request) async {
    final cityCandidates = _cityQueryCandidates(request.locationLabel);
    if (cityCandidates.isEmpty) {
      throw StateError('city unavailable for no-key weather source');
    }

    Map<String, dynamic>? root;
    Object? lastError;
    for (final city in cityCandidates) {
      try {
        final response = await client.getJson(
          Uri.https('uapis.cn', '/api/v1/misc/weather', <String, String>{
            'city': city,
            'forecast': 'true',
            'indices': 'true',
          }),
          headers: config.hasUapiToken
              ? {'Authorization': 'Bearer ${config.uapiToken.trim()}'}
              : const {},
        );
        if (response.containsKey('code') && intValue(response['code']) != 200) {
          throw StateError('UAPI weather request failed: $response');
        }
        if (!response.containsKey('weather') ||
            !response.containsKey('temperature')) {
          throw StateError('UAPI weather response missing fields: $response');
        }
        root = response;
        break;
      } catch (error) {
        lastError = error;
      }
    }

    if (root == null) {
      throw lastError is Exception
          ? lastError
          : StateError('UAPI weather unavailable');
    }

    final weatherText = stringValue(root['weather'], '\u5929\u6c14');
    final code = _normalizeWeatherText(weatherText);
    final temp = roundNum(root['temperature']);
    final humidity = intValue(root['humidity']);
    final windKmh = _windPowerToKmh(root['wind_power']?.toString());
    final windDirection = stringValue(root['wind_direction']);
    final reportTime = stringValue(root['report_time']);
    final forecast = root['forecast'] as List<dynamic>?;
    final forecastAvailable = forecast?.isNotEmpty ?? false;

    return WeatherSnapshot(
      locationLabel:
          firstNonEmpty([stringValue(root['city']), request.locationLabel]) ??
          request.locationLabel,
      updatedAt: DateTime.now(),
      currentTemp: temp,
      apparentTemp: temp,
      humidity: humidity,
      windKmh: windKmh,
      currentCode: code,
      currentDescription: weatherText,
      sourceLabel: forecastAvailable ? 'UAPI\u9884\u62a5' : 'UAPI\u5b9e\u65f6',
      reportTimeLabel: reportTime,
      forecastAvailable: forecastAvailable,
      days: _parseForecast(
        root,
        weatherText: weatherText,
        code: code,
        temp: temp,
        humidity: humidity,
        windKmh: windKmh,
        windDirection: windDirection,
      ),
    );
  }

  List<WeatherDay> _parseForecast(
    Map<String, dynamic> root, {
    required String weatherText,
    required int code,
    required int temp,
    required int humidity,
    required int windKmh,
    required String windDirection,
  }) {
    final forecast = root['forecast'] as List<dynamic>?;
    if (forecast == null || forecast.isEmpty) {
      return _buildRealtimeFallbackDays(
        weatherText: weatherText,
        code: code,
        temp: temp,
        humidity: humidity,
        windKmh: windKmh,
        windDirection: windDirection,
      );
    }

    final lifeIndices = root['life_indices'];
    return forecast.map((item) {
      final map = asMap(item, 'forecast item');
      final textDay =
          firstNonEmpty([
            stringValue(map['weather_day']),
            stringValue(map['weather']),
            weatherText,
          ]) ??
          weatherText;
      final dayCode = _normalizeWeatherText(textDay);
      var day = WeatherDay(
        date: stringValue(map['date']),
        code: dayCode,
        description: textDay,
        icon: weatherIcon(dayCode),
        high: intValue(map['temp_max'], temp),
        low: intValue(map['temp_min'], temp),
        precipitation: intValue(
          map['pop'],
          (numValue(map['precip']) > 0) ? 55 : 0,
        ),
        uv: intValue(map['uv_index']),
        windKmh: _windPowerToKmh(map['wind_scale_day']?.toString()),
        windDirection: stringValue(map['wind_dir_day']),
      );
      day = _applyUapiLifeIndices(day, lifeIndices);
      return day;
    }).toList();
  }

  WeatherDay _applyUapiLifeIndices(WeatherDay day, Object? rawLifeIndices) {
    if (rawLifeIndices == null) {
      return day;
    }
    final lifeIndices = asMap(rawLifeIndices, 'life_indices');
    return day.copyWith(
      clothingTip: _uapiLifeAdvice(lifeIndices, 'clothing'),
      umbrellaTip: _uapiLifeAdvice(lifeIndices, 'umbrella'),
      travelTip: firstNonEmpty([
        _uapiLifeAdvice(lifeIndices, 'travel'),
        _uapiLifeAdvice(lifeIndices, 'traffic'),
      ]),
      sportTip: _uapiLifeAdvice(lifeIndices, 'exercise'),
      sunProtectionTip: firstNonEmpty([
        _uapiLifeAdvice(lifeIndices, 'sunscreen'),
        _uapiLifeAdvice(lifeIndices, 'uv'),
      ]),
    );
  }

  String? _uapiLifeAdvice(Map<String, dynamic> lifeIndices, String key) {
    final item = lifeIndices[key];
    if (item == null) {
      return null;
    }
    return stringValue(asMap(item, 'life_indices.$key')['advice']);
  }

  List<WeatherDay> _buildRealtimeFallbackDays({
    required String weatherText,
    required int code,
    required int temp,
    required int humidity,
    required int windKmh,
    required String windDirection,
  }) {
    return List<WeatherDay>.generate(4, (index) {
      final hasPrecipitation =
          weatherText.contains('\u96e8') || weatherText.contains('\u96ea');
      return WeatherDay(
        date: '',
        code: code,
        description: index == 0 ? weatherText : '\u6682\u65e0\u9884\u62a5',
        icon: weatherIcon(code),
        high: temp,
        low: temp,
        precipitation: hasPrecipitation ? 55 : 0,
        uv: 0,
        windKmh: windKmh,
        windDirection: windDirection,
        clothingTip: temp <= 12
            ? '\u504f\u51c9\uff0c\u5efa\u8bae\u52a0\u5916\u5957\u3002'
            : temp <= 20
            ? '\u65e9\u665a\u504f\u51c9\uff0c\u5efa\u8bae\u52a0\u4e00\u4ef6\u8584\u5916\u5957\u3002'
            : '\u6e29\u5ea6\u8212\u9002\uff0c\u8f7b\u8584\u8863\u7269\u5373\u53ef\u3002',
        umbrellaTip: hasPrecipitation
            ? '\u5f53\u524d\u6709\u964d\u6c34\uff0c\u5efa\u8bae\u5e26\u4f1e\u3002'
            : humidity >= 85
            ? '\u6e7f\u5ea6\u8f83\u9ad8\uff0c\u7559\u610f\u77ed\u65f6\u964d\u6c34\u3002'
            : '\u5f53\u524d\u65e0\u660e\u663e\u964d\u6c34\uff0c\u53ef\u8f7b\u88c5\u51fa\u884c\u3002',
        travelTip: humidity >= 85
            ? '\u6e7f\u5ea6\u9ad8\uff0c\u7559\u610f\u8def\u9762\u6e7f\u6ed1\u3002'
            : windKmh >= 30
            ? '\u98ce\u529b\u504f\u5927\uff0c\u7559\u610f\u9635\u98ce\u3002'
            : '\u5929\u6c14\u5e73\u7a33\uff0c\u9002\u5408\u51fa\u884c\u3002',
      );
    });
  }

  List<String> _cityQueryCandidates(String label) {
    final candidates = <String>[];
    final cleaned = label.trim();
    if (cleaned.isEmpty || _coordinatePlaceholderLabel.hasMatch(cleaned)) {
      return candidates;
    }

    final parts = cleaned.split(RegExp(r'\s+'));
    for (var index = parts.length - 1; index >= 0; index -= 1) {
      _addCityCandidate(candidates, parts[index]);
    }
    _addCityCandidate(candidates, cleaned);
    return candidates;
  }

  void _addCityCandidate(List<String> candidates, String? value) {
    if (value == null) {
      return;
    }
    final candidate = value
        .replaceAll('\u7279\u522b\u884c\u653f\u533a', '')
        .replaceAll('\u5e02\u8f96\u533a', '')
        .trim();
    if (candidate.isNotEmpty && !candidates.contains(candidate)) {
      candidates.add(candidate);
    }
  }

  int _windPowerToKmh(String? windPower) {
    if (windPower == null || windPower.trim().isEmpty) {
      return 0;
    }
    final text = windPower.trim();
    if (text.contains('\u5fae\u98ce')) {
      return 5;
    }
    final match = RegExp(r'\d').firstMatch(text);
    if (match == null) {
      return 0;
    }
    return (int.parse(match.group(0)!) * 6.5).round();
  }

  int _normalizeWeatherText(String text) {
    if (text.contains('\u96f7')) return 95;
    if (text.contains('\u96ea')) return 71;
    if (text.contains('\u96e8')) return 61;
    if (text.contains('\u973e')) return 451;
    if (text.contains('\u96fe')) return 45;
    if (text.contains('\u6674')) return 0;
    if (text.contains('\u4e91')) return 2;
    if (text.contains('\u9634')) return 3;
    return 3;
  }
}
