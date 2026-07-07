import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/app_config.dart';

void main() {
  test('AppConfig supplies documented defaults', () {
    const config = AppConfig();

    expect(config.gptsApiBaseUrl, 'https://api.gptsapi.net/v1');
    expect(config.gptsApiModel, 'gpt-5.4-nano');
    expect(config.hasUapiToken, isFalse);
    expect(config.hasGptsApiKey, isFalse);
  });
}
