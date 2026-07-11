import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/app_config.dart';
import 'package:home_info_clock/services/ai_location_service.dart';
import 'package:home_info_clock/services/http_json_client.dart';

class _FakeJsonHttpClient extends JsonHttpClient {
  _FakeJsonHttpClient(this.onPost);

  final Future<Map<String, dynamic>> Function(
    Uri uri,
    Map<String, Object?> body,
    Map<String, String> headers,
  )
  onPost;

  @override
  Future<Map<String, dynamic>> postJson(
    Uri uri,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
  }) {
    return onPost(uri, body, headers);
  }
}

void main() {
  test(
    'AiLocationService resolves free-form text to a manual location',
    () async {
      Uri? requestedUri;
      Map<String, Object?>? requestedBody;
      Map<String, String>? requestedHeaders;
      final service = AiLocationService(
        client: _FakeJsonHttpClient((uri, body, headers) async {
          requestedUri = uri;
          requestedBody = body;
          requestedHeaders = headers;
          return <String, dynamic>{
            'choices': [
              {
                'message': {
                  'content':
                      '```json {"label":"日本 东京","latitude":35.6762,"longitude":139.6503} ```',
                },
              },
            ],
          };
        }),
        config: const AppConfig(
          gptsApiKey: ' secret ',
          gptsApiBaseUrl: 'https://api.gptsapi.net/v1/',
          gptsApiModel: 'gpt-test',
        ),
      );

      final location = await service.resolve('东京涩谷');

      expect(
        requestedUri.toString(),
        'https://api.gptsapi.net/v1/chat/completions',
      );
      expect(requestedHeaders?['Authorization'], 'Bearer secret');
      expect(requestedBody?['model'], 'gpt-test');
      expect(requestedBody.toString(), contains('东京涩谷'));
      expect(location.label, '日本 东京');
      expect(location.latitude, 35.6762);
      expect(location.longitude, 139.6503);
    },
  );

  test(
    'AiLocationService rejects missing API configuration without a request',
    () async {
      var calls = 0;
      final service = AiLocationService(
        client: _FakeJsonHttpClient((_, _, _) async {
          calls += 1;
          return <String, dynamic>{};
        }),
        config: const AppConfig(),
      );

      await expectLater(service.resolve('新加坡'), throwsA(isA<StateError>()));
      expect(calls, 0);
    },
  );

  test('AiLocationService rejects an invalid location response', () async {
    final service = AiLocationService(
      client: _FakeJsonHttpClient((_, _, _) async {
        return <String, dynamic>{
          'choices': [
            {
              'message': {
                'content': '{"label":"","latitude":95,"longitude":181}',
              },
            },
          ],
        };
      }),
      config: const AppConfig(gptsApiKey: 'secret'),
    );

    await expectLater(service.resolve('不明地点'), throwsA(isA<FormatException>()));
  });
}
