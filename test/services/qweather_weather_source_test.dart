import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/app_config.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/services/http_json_client.dart';
import 'package:home_info_clock/services/qweather_weather_source.dart';

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
  test('QWeatherWeatherSource parses API-key forecast responses', () async {
    final requests = <Uri>[];
    final requestHeaders = <Map<String, String>>[];
    final client = FakeJsonHttpClient(
      onGet: (uri, headers) async {
        requests.add(uri);
        requestHeaders.add(headers);
        if (uri.path.endsWith('/weather/now')) {
          return <String, dynamic>{
            'code': '200',
            'now': {
              'temp': '31',
              'feelsLike': '35',
              'humidity': '84',
              'windSpeed': '18',
              'icon': '305',
              'text': '\u5c0f\u96e8',
            },
          };
        }
        if (uri.path.endsWith('/weather/7d')) {
          return <String, dynamic>{
            'code': '200',
            'daily': [
              {
                'fxDate': '2026-07-07',
                'iconDay': '101',
                'textDay': '\u591a\u4e91',
                'tempMax': '33',
                'tempMin': '27',
                'precip': '0.5',
                'uvIndex': '6',
                'windSpeedDay': '14',
              },
              {
                'fxDate': '2026-07-08',
                'iconDay': '302',
                'textDay': '\u96f7\u9635\u96e8',
                'tempMax': '30',
                'tempMin': '25',
                'precip': '12.2',
                'uvIndex': '3',
                'windSpeedDay': '22',
              },
            ],
          };
        }
        return <String, dynamic>{
          'code': '200',
          'daily': [
            {
              'date': '2026-07-07',
              'type': '3',
              'text': '\u77ed\u8896\u5373\u53ef',
            },
            {
              'date': '2026-07-07',
              'type': '6',
              'text': '\u51fa\u95e8\u6162\u884c',
            },
            {
              'date': '2026-07-08',
              'type': '1',
              'text': '\u51cf\u5c11\u6237\u5916',
            },
            {
              'date': '2026-07-08',
              'type': '16',
              'text': '\u6ce8\u610f\u9632\u6652',
            },
          ],
        };
      },
    );
    final source = QWeatherWeatherSource(
      client: client,
      config: const AppConfig(qweatherApiKey: ' api-key '),
    );

    final result = await source.fetch(
      const WeatherRequest(
        latitude: 31.23,
        longitude: 121.47,
        locationLabel: '\u4e0a\u6d77',
      ),
    );

    expect(requests, hasLength(3));
    expect(requests.first.host, 'devapi.qweather.com');
    expect(requests.first.queryParameters['location'], '121.47,31.23');
    expect(requestHeaders, everyElement({'X-QW-Api-Key': 'api-key'}));
    expect(result.sourceLabel, '\u548c\u98ce\u9884\u62a5');
    expect(result.currentCode, 61);
    expect(result.currentDescription, '\u5c0f\u96e8');
    expect(result.currentTemp, 31);
    expect(result.apparentTemp, 35);
    expect(result.humidity, 84);
    expect(result.windKmh, 18);
    expect(result.days, hasLength(2));
    expect(result.days.first.code, 2);
    expect(result.days.first.precipitation, 45);
    expect(result.days.first.clothingTip, '\u77ed\u8896\u5373\u53ef');
    expect(result.days.first.travelTip, '\u51fa\u95e8\u6162\u884c');
    expect(result.days[1].code, 61);
    expect(result.days[1].precipitation, 90);
    expect(result.days[1].sportTip, '\u51cf\u5c11\u6237\u5916');
    expect(result.days[1].sunProtectionTip, '\u6ce8\u610f\u9632\u6652');
  });

  test('QWeatherWeatherSource selects Bearer auth for JWT config', () async {
    final requestHeaders = <Map<String, String>>[];
    final client = FakeJsonHttpClient(
      onGet: (uri, headers) async {
        requestHeaders.add(headers);
        if (uri.path.endsWith('/weather/now')) {
          return <String, dynamic>{
            'code': '200',
            'now': {
              'temp': '29',
              'feelsLike': '31',
              'humidity': '78',
              'windSpeed': '9',
              'icon': '100',
              'text': '\u6674',
            },
          };
        }
        if (uri.path.endsWith('/weather/7d')) {
          return <String, dynamic>{
            'code': '200',
            'daily': [
              {
                'fxDate': '2026-07-07',
                'iconDay': '100',
                'textDay': '\u6674',
                'tempMax': '32',
                'tempMin': '26',
                'precip': '0',
                'uvIndex': '9',
                'windSpeedDay': '12',
              },
            ],
          };
        }
        return <String, dynamic>{'code': '200', 'daily': []};
      },
    );
    final source = QWeatherWeatherSource(
      client: client,
      config: const AppConfig(
        qweatherJwtProjectId: 'project-id',
        qweatherJwtKeyId: 'key-id',
        qweatherJwtPrivateKey:
            '-----BEGIN PRIVATE KEY-----\\nabc123\\n-----END PRIVATE KEY-----',
      ),
      jwtSigner: (_) async => 'header.payload.signature',
    );

    final result = await source.fetch(
      const WeatherRequest(
        latitude: 31.23,
        longitude: 121.47,
        locationLabel: '\u4e0a\u6d77',
      ),
    );

    expect(
      requestHeaders,
      everyElement({'Authorization': 'Bearer header.payload.signature'}),
    );
    expect(result.currentCode, 0);
    expect(result.days.single.code, 0);
  });

  test('QWeatherWeatherSource signs JWT config with Ed25519 key', () async {
    final requestHeaders = <Map<String, String>>[];
    final client = FakeJsonHttpClient(
      onGet: (uri, headers) async {
        requestHeaders.add(headers);
        if (uri.path.endsWith('/weather/now')) {
          return <String, dynamic>{
            'code': '200',
            'now': {
              'temp': '29',
              'feelsLike': '31',
              'humidity': '78',
              'windSpeed': '9',
              'icon': '100',
              'text': '\u6674',
            },
          };
        }
        if (uri.path.endsWith('/weather/7d')) {
          return <String, dynamic>{
            'code': '200',
            'daily': [
              {
                'fxDate': '2026-07-07',
                'iconDay': '100',
                'textDay': '\u6674',
                'tempMax': '32',
                'tempMin': '26',
                'precip': '0',
                'uvIndex': '9',
                'windSpeedDay': '12',
              },
            ],
          };
        }
        return <String, dynamic>{'code': '200', 'daily': []};
      },
    );
    final seed = List<int>.generate(32, (index) => index + 1);
    final keyPair = await Ed25519().newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    final now = DateTime.utc(2026, 7, 7, 8, 30);
    final source = QWeatherWeatherSource(
      client: client,
      config: AppConfig(
        qweatherJwtProjectId: 'project-id',
        qweatherJwtKeyId: 'key-id',
        qweatherJwtPrivateKey: _ed25519Pkcs8Pem(
          seed,
          publicKeyBytes: publicKey.bytes,
        ),
      ),
      now: () => now,
    );

    await source.fetch(
      const WeatherRequest(
        latitude: 31.23,
        longitude: 121.47,
        locationLabel: '\u4e0a\u6d77',
      ),
    );

    final token = requestHeaders.first['Authorization']!.substring(
      'Bearer '.length,
    );
    final parts = token.split('.');
    expect(parts, hasLength(3));
    expect(requestHeaders, everyElement({'Authorization': 'Bearer $token'}));
    expect(_decodeJwtJson(parts[0]), {'alg': 'EdDSA', 'kid': 'key-id'});
    expect(_decodeJwtJson(parts[1]), {
      'sub': 'project-id',
      'iat': now.millisecondsSinceEpoch ~/ 1000 - 30,
      'exp': now.millisecondsSinceEpoch ~/ 1000 + 23 * 60 * 60,
    });

    final signature = Signature(
      base64Url.decode(_paddedBase64Url(parts[2])),
      publicKey: publicKey,
    );
    expect(
      await Ed25519().verify(
        utf8.encode('${parts[0]}.${parts[1]}'),
        signature: signature,
      ),
      isTrue,
    );
  });
}

Map<String, dynamic> _decodeJwtJson(String value) {
  return jsonDecode(utf8.decode(base64Url.decode(_paddedBase64Url(value))))
      as Map<String, dynamic>;
}

String _ed25519Pkcs8Pem(List<int> seed, {List<int>? publicKeyBytes}) {
  final trailingPublicKey = publicKeyBytes == null
      ? const <int>[]
      : <int>[0xa1, 0x23, 0x03, 0x21, 0x00, ...publicKeyBytes];
  final der = <int>[
    0x30,
    0x2e + trailingPublicKey.length,
    0x02,
    0x01,
    0x00,
    0x30,
    0x05,
    0x06,
    0x03,
    0x2b,
    0x65,
    0x70,
    0x04,
    0x22,
    0x04,
    0x20,
    ...seed,
    ...trailingPublicKey,
  ];
  return '-----BEGIN PRIVATE KEY-----\\n'
      '${base64.encode(der)}\\n'
      '-----END PRIVATE KEY-----';
}

String _paddedBase64Url(String value) {
  return value.padRight(value.length + (4 - value.length % 4) % 4, '=');
}
