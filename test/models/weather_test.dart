import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/weather.dart';

void main() {
  test('WeatherSnapshot exposes today and tomorrow safely', () {
    final snapshot = WeatherSnapshot(
      locationLabel: '涓婃捣 娴︿笢',
      updatedAt: DateTime(2026, 7, 7, 9, 0),
      currentTemp: 31,
      apparentTemp: 34,
      humidity: 72,
      windKmh: 12,
      currentCode: 2,
      currentDescription: '澶氫簯',
      sourceLabel: 'UAPI棰勬姤',
      reportTimeLabel: '09:00',
      days: const [
        WeatherDay(date: '2026-07-07', code: 2, description: '澶氫簯', high: 33, low: 27),
        WeatherDay(date: '2026-07-08', code: 61, description: '灏忛洦', high: 31, low: 26),
      ],
    );

    expect(snapshot.today?.description, '澶氫簯');
    expect(snapshot.tomorrow?.description, '灏忛洦');
  });
}
