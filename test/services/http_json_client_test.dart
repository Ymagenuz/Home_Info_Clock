import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/services/http_json_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('getJson throws TimeoutException when GET does not complete', () async {
    final pending = Completer<http.Response>();
    final client = JsonHttpClient(
      client: MockClient((_) => pending.future),
      timeout: const Duration(milliseconds: 5),
    );

    await expectLater(
      client.getJson(Uri.parse('https://example.test/weather')),
      throwsA(isA<TimeoutException>()),
    );
  });

  test(
    'postJson throws TimeoutException when POST does not complete',
    () async {
      final pending = Completer<http.Response>();
      final client = JsonHttpClient(
        client: MockClient((_) => pending.future),
        timeout: const Duration(milliseconds: 5),
      );

      await expectLater(
        client.postJson(Uri.parse('https://example.test/advice'), const {
          'prompt': 'tomorrow',
        }),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}
