import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/app_config.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/services/ai_advice_service.dart';
import 'package:home_info_clock/services/http_json_client.dart';

class FakeJsonHttpClient extends JsonHttpClient {
  FakeJsonHttpClient({this.onPost});

  final Future<Map<String, dynamic>> Function(
    Uri uri,
    Map<String, Object?> body,
    Map<String, String> headers,
  )?
  onPost;

  @override
  Future<Map<String, dynamic>> postJson(
    Uri uri,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
  }) {
    return onPost!(uri, body, headers);
  }
}

WeatherSnapshot buildSnapshot() {
  return WeatherSnapshot(
    locationLabel: '\u4e0a\u6d77',
    updatedAt: DateTime(2026, 7, 7, 9),
    currentTemp: 30,
    apparentTemp: 31,
    humidity: 72,
    windKmh: 12,
    currentCode: 2,
    currentDescription: '\u591a\u4e91',
    sourceLabel: 'Open-Meteo',
    reportTimeLabel: '09:00',
    days: const [
      WeatherDay(
        date: '2026-07-07',
        code: 2,
        description: '\u591a\u4e91',
        high: 32,
        low: 26,
      ),
      WeatherDay(
        date: '2026-07-08',
        code: 61,
        description: '\u96e8',
        high: 30,
        low: 25,
        precipitation: 80,
        uv: 4,
        windKmh: 18,
        windDirection: '\u4e1c\u5357\u98ce',
      ),
    ],
  );
}

void main() {
  test('cleanAdvice trims newlines and caps length', () {
    final cleaned = AiAdviceService.cleanAdvice(
      '  \u5e26\u8f7b\u4fbf\u96e8\u4f1e\n\u6ce8\u610f\u8def\u6ed1  ',
    );

    expect(
      cleaned,
      '\u5e26\u8f7b\u4fbf\u96e8\u4f1e \u6ce8\u610f\u8def\u6ed1\u3002',
    );
  });

  test('cleanAdvice returns null for empty text', () {
    expect(AiAdviceService.cleanAdvice('   '), isNull);
  });

  test('applyAdvice updates tomorrow tips and appends source', () async {
    Uri? requestedUri;
    Map<String, Object?>? requestBody;
    Map<String, String>? requestHeaders;
    final client = FakeJsonHttpClient(
      onPost: (uri, body, headers) async {
        requestedUri = uri;
        requestBody = body;
        requestHeaders = headers;
        return <String, dynamic>{
          'choices': [
            {
              'message': {
                'content':
                    '```json {"clothing":"\\u77ed\\u8896\\u51fa\\u95e8","umbrella":"\\u5e26\\u8f7b\\u4fbf\\u96e8\\u4f1e","travel":"\\u5730\\u94c1\\u66f4\\u7a33\\u59a5"} ```',
              },
            },
          ],
        };
      },
    );
    final service = AiAdviceService(
      client: client,
      config: const AppConfig(
        gptsApiKey: ' secret ',
        gptsApiBaseUrl: 'https://api.gptsapi.net/v1/',
        gptsApiModel: 'gpt-test',
      ),
    );

    final result = await service.applyAdvice(buildSnapshot());

    expect(
      requestedUri.toString(),
      'https://api.gptsapi.net/v1/chat/completions',
    );
    expect(requestHeaders?['Authorization'], 'Bearer secret');
    expect(requestBody?['model'], 'gpt-test');
    expect(result.sourceLabel, 'Open-Meteo+AI\u5efa\u8bae');
    expect(result.days[1].clothingTip, '\u77ed\u8896\u51fa\u95e8\u3002');
    expect(result.days[1].umbrellaTip, '\u5e26\u8f7b\u4fbf\u96e8\u4f1e\u3002');
    expect(result.days[1].travelTip, '\u5730\u94c1\u66f4\u7a33\u59a5\u3002');
  });

  test(
    'applyAdvice returns original snapshot when api key is missing',
    () async {
      final service = AiAdviceService(
        client: FakeJsonHttpClient(),
        config: const AppConfig(),
      );
      final snapshot = buildSnapshot();

      final result = await service.applyAdvice(snapshot);

      expect(identical(result, snapshot), isTrue);
    },
  );
}
