import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../models/app_config.dart';
import '../models/weather.dart';
import 'http_json_client.dart';
import 'local_weather_advice.dart';
import 'weather_service_support.dart';
import 'weather_source.dart';

typedef QWeatherJwtSigner =
    Future<String> Function(QWeatherJwtSigningRequest request);

class QWeatherJwtSigningRequest {
  const QWeatherJwtSigningRequest({
    required this.keyId,
    required this.projectId,
    required this.privateKeyPem,
    required this.issuedAtSeconds,
    required this.expiresAtSeconds,
    required this.signingInput,
  });

  final String keyId;
  final String projectId;
  final String privateKeyPem;
  final int issuedAtSeconds;
  final int expiresAtSeconds;
  final String signingInput;
}

class QWeatherWeatherSource implements WeatherSource {
  const QWeatherWeatherSource({
    required this.client,
    required this.config,
    this.jwtSigner,
    this.now = DateTime.now,
  });

  final JsonHttpClient client;
  final AppConfig config;
  final QWeatherJwtSigner? jwtSigner;
  final DateTime Function() now;

  @override
  Future<WeatherSnapshot> fetch(WeatherRequest request) async {
    final locationParam =
        '${request.longitude.toStringAsFixed(2)},${request.latitude.toStringAsFixed(2)}';
    final basePath = '/v7';
    final headers = await _authHeaders();
    final host = config.qweatherApiHost;
    final fetchedAt = now();

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
    Map<String, dynamic> indicesRoot = const {};
    try {
      indicesRoot = await _readQWeatherJson(
        Uri.https(host, '$basePath/indices/3d', {
          'location': locationParam,
          'type': '1,3,6,16',
          'lang': 'zh',
        }),
        headers,
      );
    } catch (_) {
      // Lifestyle indices enrich the forecast but must not make it unusable.
    }

    final current = asMap(nowRoot['now'], 'now');
    final currentCode = _normalizeQWeatherIcon(
      stringValue(current['icon'], '999'),
    );

    return ensureLocalWeatherAdvice(
      WeatherSnapshot(
        locationLabel: request.locationLabel,
        updatedAt: fetchedAt,
        currentTemp: intValue(current['temp']),
        apparentTemp: intValue(current['feelsLike'], intValue(current['temp'])),
        humidity: intValue(current['humidity']),
        windKmh: intValue(current['windSpeed']),
        currentCode: currentCode,
        currentDescription: stringValue(
          current['text'],
          weatherDescription(currentCode),
        ),
        sourceLabel: '\u548c\u98ce\u9884\u62a5',
        reportTimeLabel: formatHm(fetchedAt),
        forecastAvailable: true,
        days: _parseDailyForecast(
          asMap(dailyRoot, 'dailyRoot'),
          _parseIndices(indicesRoot),
        ),
      ),
    );
  }

  Future<Map<String, String>> _authHeaders() async {
    if (config.hasQWeatherApiKey) {
      return {'X-QW-Api-Key': config.qweatherApiKey.trim()};
    }
    if (config.hasQWeatherJwtConfig) {
      return {'Authorization': 'Bearer ${await _buildJwt()}'};
    }
    throw StateError('weather forecast unavailable');
  }

  Future<String> _buildJwt() async {
    final nowSeconds = now().millisecondsSinceEpoch ~/ 1000;
    final issuedAtSeconds = nowSeconds - 30;
    final expiresAtSeconds = nowSeconds + (23 * 60 * 60);
    final header = jsonEncode(<String, String>{
      'alg': 'EdDSA',
      'kid': config.qweatherJwtKeyId.trim(),
    });
    final payload = jsonEncode(<String, Object>{
      'sub': config.qweatherJwtProjectId.trim(),
      'iat': issuedAtSeconds,
      'exp': expiresAtSeconds,
    });
    final signingInput =
        '${_base64UrlEncodeUtf8(header)}.${_base64UrlEncodeUtf8(payload)}';
    final signer = jwtSigner ?? _defaultJwtSigner;
    return signer(
      QWeatherJwtSigningRequest(
        keyId: config.qweatherJwtKeyId.trim(),
        projectId: config.qweatherJwtProjectId.trim(),
        privateKeyPem: config.qweatherJwtPrivateKey,
        issuedAtSeconds: issuedAtSeconds,
        expiresAtSeconds: expiresAtSeconds,
        signingInput: signingInput,
      ),
    );
  }

  Future<String> _defaultJwtSigner(QWeatherJwtSigningRequest request) async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPairFromSeed(
      _ed25519PrivateSeedFromPkcs8Pem(request.privateKeyPem),
    );
    final signature = await algorithm.sign(
      utf8.encode(request.signingInput),
      keyPair: keyPair,
    );
    return '${request.signingInput}.${_base64UrlEncodeBytes(signature.bytes)}';
  }

  String _base64UrlEncodeUtf8(String value) {
    return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  }

  String _base64UrlEncodeBytes(List<int> value) {
    return base64Url.encode(value).replaceAll('=', '');
  }

  List<int> _ed25519PrivateSeedFromPkcs8Pem(String privateKeyPem) {
    final normalizedKey = privateKeyPem
        .replaceAll('\\n', '\n')
        .replaceAll('-----BEGIN PRIVATE KEY-----', '')
        .replaceAll('-----END PRIVATE KEY-----', '')
        .replaceAll(RegExp(r'\s+'), '');
    final der = base64Decode(normalizedKey);
    final rootReader = _DerReader(der);
    final root = rootReader.readValue(0x30);
    if (!rootReader.isDone) {
      throw const FormatException('Unexpected trailing data in PKCS8 key');
    }

    final reader = _DerReader(root);
    reader.readValue(0x02);
    final algorithm = reader.readValue(0x30);
    const ed25519ObjectId = [0x06, 0x03, 0x2b, 0x65, 0x70];
    if (!_containsBytes(algorithm, ed25519ObjectId)) {
      throw const FormatException(
        'QWeather JWT private key must be an Ed25519 PKCS8 PEM key',
      );
    }

    final privateKey = reader.readValue(0x04);
    if (privateKey.length == 32) {
      return privateKey;
    }
    final privateKeyReader = _DerReader(privateKey);
    final seed = privateKeyReader.readValue(0x04);
    if (!privateKeyReader.isDone || seed.length != 32) {
      throw const FormatException(
        'QWeather JWT private key must contain a 32-byte Ed25519 seed',
      );
    }
    return seed;
  }

  bool _containsBytes(List<int> value, List<int> pattern) {
    if (pattern.isEmpty || pattern.length > value.length) {
      return false;
    }
    for (var start = 0; start <= value.length - pattern.length; start += 1) {
      var matches = true;
      for (var offset = 0; offset < pattern.length; offset += 1) {
        if (value[start + offset] != pattern[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return true;
      }
    }
    return false;
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

class _DerReader {
  _DerReader(this._bytes);

  final List<int> _bytes;
  int _offset = 0;

  bool get isDone => _offset >= _bytes.length;

  List<int> readValue(int expectedTag) {
    if (_offset >= _bytes.length) {
      throw const FormatException('Unexpected end of DER data');
    }
    final tag = _bytes[_offset];
    _offset += 1;
    if (tag != expectedTag) {
      throw FormatException('Unexpected DER tag $tag');
    }
    final length = _readLength();
    if (_offset + length > _bytes.length) {
      throw const FormatException('DER length exceeds input');
    }
    final value = _bytes.sublist(_offset, _offset + length);
    _offset += length;
    return value;
  }

  int _readLength() {
    if (_offset >= _bytes.length) {
      throw const FormatException('Missing DER length');
    }
    final first = _bytes[_offset];
    _offset += 1;
    if ((first & 0x80) == 0) {
      return first;
    }
    final byteCount = first & 0x7f;
    if (byteCount == 0 ||
        byteCount > 4 ||
        _offset + byteCount > _bytes.length) {
      throw const FormatException('Invalid DER length');
    }
    var length = 0;
    for (var index = 0; index < byteCount; index += 1) {
      length = (length << 8) | _bytes[_offset + index];
    }
    _offset += byteCount;
    return length;
  }
}
