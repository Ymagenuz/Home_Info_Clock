import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/battery_status.dart';
import 'package:home_info_clock/models/timer_state.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/services/cache_service.dart';
import 'package:home_info_clock/state/home_controller.dart';
import 'package:home_info_clock/state/timer_controller.dart';

import '../support/live_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HomeController toggles simple mode', () {
    final controller = HomeController.preview();

    expect(controller.isSimpleMode, isFalse);
    controller.toggleSimpleMode();
    expect(controller.isSimpleMode, isTrue);
  });

  test('HomeController preview exposes weather and battery state', () {
    final controller = HomeController.preview();

    expect(controller.weather, isNotNull);
    expect(controller.weather!.days, hasLength(2));
    expect(controller.battery.level, 86);
    expect(controller.battery.isCharging, isTrue);
  });

  test('HomeController updates weather and battery state', () {
    final controller = HomeController();
    final weather = WeatherSnapshot(
      locationLabel: 'Test City',
      updatedAt: DateTime(2026, 7, 7, 9, 0),
      currentTemp: 22,
      apparentTemp: 23,
      humidity: 50,
      windKmh: 8,
      currentCode: 1,
      currentDescription: 'Clear',
      sourceLabel: 'Test',
      reportTimeLabel: '09:00',
    );

    controller.setWeather(weather);
    controller.setBattery(const BatteryStatus(level: 42, isCharging: false));

    expect(controller.weather, same(weather));
    expect(controller.battery.level, 42);
    expect(controller.battery.isCharging, isFalse);
  });

  test('initialize restores cached weather and timer state', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final cache = CacheService(preferences);
    final now = DateTime(2026, 7, 8, 9, 0);
    final cachedWeather = testWeatherSnapshot(
      locationLabel: 'Cached City',
      updatedAt: now.subtract(const Duration(minutes: 10)),
      sourceLabel: 'Cache',
    );
    await cache.saveWeather(cachedWeather);
    await cache.saveTimer(const TimerState(minutes: 12, seconds: 5));

    final platform = FakePlatformGateway();
    addTearDown(platform.close);
    final timerController = TimerController();
    final fetcher = RecordingWeatherFetcher(
      testWeatherSnapshot(locationLabel: 'Fetched City', updatedAt: now),
    );
    final controller = HomeController(
      cache: cache,
      fetchWeather: fetcher.call,
      platform: platform,
      timerController: timerController,
      now: () => now,
    );

    await controller.initialize();

    expect(controller.weather?.locationLabel, 'Cached City');
    expect(controller.battery.level, 55);
    expect(timerController.state.minutes, 12);
    expect(timerController.state.seconds, 5);
    expect(platform.permissionRequests, 1);
    expect(platform.locationResolves, 1);
    expect(fetcher.calls, 0);
  });

  test('initialize refreshes stale cached weather', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final cache = CacheService(preferences);
    final now = DateTime(2026, 7, 8, 9, 0);
    await cache.saveWeather(
      testWeatherSnapshot(
        locationLabel: 'Old City',
        updatedAt: now.subtract(const Duration(minutes: 31)),
      ),
    );

    final platform = FakePlatformGateway();
    addTearDown(platform.close);
    final fetchedWeather = testWeatherSnapshot(
      locationLabel: 'Fetched City',
      updatedAt: now,
      sourceLabel: 'Network',
    );
    final fetcher = RecordingWeatherFetcher(fetchedWeather);
    final controller = HomeController(
      cache: cache,
      fetchWeather: fetcher.call,
      platform: platform,
      timerController: TimerController(),
      now: () => now,
    );

    await controller.initialize();

    expect(fetcher.calls, 1);
    expect(fetcher.lastRequest?.locationLabel, 'Live City');
    expect(controller.weather, same(fetchedWeather));
    expect(cache.loadWeather()?.locationLabel, 'Fetched City');
  });

  test('refreshWeather persists fetched weather', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final cache = CacheService(preferences);
    final platform = FakePlatformGateway();
    addTearDown(platform.close);
    final fetchedWeather = testWeatherSnapshot(
      locationLabel: 'Fetched City',
      sourceLabel: 'Network',
    );
    final fetcher = RecordingWeatherFetcher(fetchedWeather);
    final controller = HomeController(
      cache: cache,
      fetchWeather: fetcher.call,
      platform: platform,
      timerController: TimerController(),
      now: () => DateTime(2026, 7, 8, 9, 0),
    );

    await controller.refreshWeather(force: true);

    expect(fetcher.calls, 1);
    expect(fetcher.lastRequest?.latitude, 31.2304);
    expect(controller.weather, same(fetchedWeather));
    expect(cache.loadWeather()?.locationLabel, 'Fetched City');
  });

  test('openBilibili delegates to platform service', () async {
    final platform = FakePlatformGateway();
    addTearDown(platform.close);
    final controller = HomeController(platform: platform);

    await controller.openBilibili();

    expect(platform.openBilibiliCalls, 1);
  });
}
