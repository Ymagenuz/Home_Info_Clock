import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/timer_state.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/services/cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('CacheService round trips timer state', () async {
    final cache = CacheService(await SharedPreferences.getInstance());
    final state = TimerState.runningUntil(DateTime(2026, 7, 7, 9, 5));

    await cache.saveTimer(state);
    final restored = cache.loadTimer();

    expect(restored.isRunning, isTrue);
    expect(restored.endsAt, DateTime(2026, 7, 7, 9, 5));
  });

  test('CacheService round trips weather snapshot', () async {
    final cache = CacheService(await SharedPreferences.getInstance());
    final snapshot = WeatherSnapshot(
      locationLabel: '\u4e0a\u6d77',
      updatedAt: DateTime(2026, 7, 7, 9),
      currentTemp: 30,
      apparentTemp: 33,
      humidity: 70,
      windKmh: 12,
      currentCode: 2,
      currentDescription: '\u591a\u4e91',
      sourceLabel: 'UAPI\u9884\u62a5',
      reportTimeLabel: '09:00',
      days: const [
        WeatherDay(
          date: '2026-07-07',
          code: 2,
          description: '\u591a\u4e91',
          high: 33,
          low: 27,
        ),
      ],
    );

    await cache.saveWeather(snapshot);
    final restored = cache.loadWeather();

    expect(restored?.locationLabel, '\u4e0a\u6d77');
    expect(restored?.today?.high, 33);
  });
}
