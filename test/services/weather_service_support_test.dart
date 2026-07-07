import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/services/weather_service_support.dart';

void main() {
  test('numeric helpers return fallback for malformed strings', () {
    expect(roundNum('N/A', 7), 7);
    expect(intValue('--', 8), 8);
    expect(numValue('\u6682\u65e0', 9.5), 9.5);
  });
}
