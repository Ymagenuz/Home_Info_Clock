import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/battery_status.dart';
import 'package:home_info_clock/models/timer_state.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/services/cache_service.dart';
import 'package:home_info_clock/services/platform_service.dart';
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

  test(
    'concurrent initial manual and forced refresh share one live request',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = _RecordingCacheService(preferences);
      final permission = Completer<bool>();
      final location = Completer<DeviceLocation?>();
      final fetch = Completer<WeatherSnapshot>();
      final platform = FakePlatformGateway(
        requestLocationPermissionOverride: () => permission.future,
        resolveLocationOverride: () => location.future,
      );
      addTearDown(platform.close);
      final fetchedWeather = testWeatherSnapshot(
        locationLabel: 'Fetched City',
        sourceLabel: 'Network',
      );
      final fetcher = _CompletingWeatherFetcher(fetch.future);
      final controller = HomeController(
        cache: cache,
        fetchWeather: fetcher.call,
        platform: platform,
      );

      final initialization = controller.initialize();
      final manualRefresh = controller.refreshWeather(force: true);
      final forcedRefresh = controller.refreshWeather(force: true);
      await Future<void>.delayed(Duration.zero);

      expect(platform.permissionRequests, 1);
      permission.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(platform.locationResolves, 1);
      location.complete(platform.location);
      await Future<void>.delayed(Duration.zero);
      expect(fetcher.calls, 1);
      fetch.complete(fetchedWeather);

      await Future.wait([initialization, manualRefresh, forcedRefresh]);

      expect(platform.permissionRequests, 1);
      expect(platform.locationResolves, 1);
      expect(fetcher.calls, 1);
      expect(cache.weatherWrites, 1);
      expect(controller.weather, same(fetchedWeather));
    },
  );

  test('dispose during battery read stops initialization', () async {
    final batteryRead = Completer<BatteryStatus>();
    final platform = FakePlatformGateway(
      readBatteryStatusOverride: () => batteryRead.future,
    );
    addTearDown(platform.close);
    final controller = HomeController(
      fetchWeather: RecordingWeatherFetcher(testWeatherSnapshot()).call,
      platform: platform,
    );

    final initialization = controller.initialize();
    expect(platform.batteryReads, 1);

    controller.dispose();
    batteryRead.complete(const BatteryStatus(level: 77, isCharging: false));

    await expectLater(initialization, completes);
    expect(platform.batteryWatches, 0);
    expect(platform.permissionRequests, 0);
  });

  test('dispose during permission request stops location work', () async {
    final permission = Completer<bool>();
    final platform = FakePlatformGateway(
      requestLocationPermissionOverride: () => permission.future,
    );
    addTearDown(platform.close);
    final fetcher = RecordingWeatherFetcher(testWeatherSnapshot());
    final controller = HomeController(
      fetchWeather: fetcher.call,
      platform: platform,
    );

    final initialization = controller.initialize();
    await _waitUntil(() => platform.permissionRequests == 1);

    controller.dispose();
    permission.complete(true);

    await expectLater(initialization, completes);
    expect(platform.locationResolves, 0);
    expect(fetcher.calls, 0);
  });

  test('dispose during location resolve stops weather fetch', () async {
    final location = Completer<DeviceLocation?>();
    final platform = FakePlatformGateway(
      resolveLocationOverride: () => location.future,
    );
    addTearDown(platform.close);
    final fetcher = RecordingWeatherFetcher(testWeatherSnapshot());
    final controller = HomeController(
      fetchWeather: fetcher.call,
      platform: platform,
    );

    final initialization = controller.initialize();
    await _waitUntil(() => platform.locationResolves == 1);

    controller.dispose();
    location.complete(platform.location);

    await expectLater(initialization, completes);
    expect(fetcher.calls, 0);
  });

  test('dispose during weather fetch drops the late result', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final cache = _RecordingCacheService(preferences);
    final fetch = Completer<WeatherSnapshot>();
    final fetcher = _CompletingWeatherFetcher(fetch.future);
    final platform = FakePlatformGateway();
    addTearDown(platform.close);
    final controller = HomeController(
      cache: cache,
      fetchWeather: fetcher.call,
      platform: platform,
    );

    final initialization = controller.initialize();
    await _waitUntil(() => fetcher.calls == 1);

    controller.dispose();
    fetch.complete(testWeatherSnapshot(locationLabel: 'Late City'));

    await expectLater(initialization, completes);
    expect(controller.weather, isNull);
    expect(cache.weatherWrites, 0);
  });

  test(
    'battery polling refreshes level without events and stops on dispose',
    () async {
      final pollRead = Completer<BatteryStatus>();
      var isInitialRead = true;
      final platform = FakePlatformGateway(
        readBatteryStatusOverride: () {
          if (isInitialRead) {
            isInitialRead = false;
            return Future<BatteryStatus>.value(
              const BatteryStatus(level: 10, isCharging: false),
            );
          }
          return pollRead.future;
        },
      );
      addTearDown(platform.close);
      final controller = HomeController(
        platform: platform,
        batteryPollingInterval: const Duration(milliseconds: 5),
      );

      await controller.initialize();
      expect(controller.battery.level, 10);
      expect(platform.batteryWatches, 1);

      await _waitUntil(() => platform.batteryReads == 2);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(platform.batteryReads, 2);

      pollRead.complete(const BatteryStatus(level: 66, isCharging: false));
      await _waitUntil(() => controller.battery.level == 66);
      expect(controller.battery.level, 66);

      controller.dispose();
      final readsAfterDispose = platform.batteryReads;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(platform.batteryReads, readsAfterDispose);
    },
  );

  test('dispose during battery poll drops its late result', () async {
    final pollRead = Completer<BatteryStatus>();
    var isInitialRead = true;
    final platform = FakePlatformGateway(
      readBatteryStatusOverride: () {
        if (isInitialRead) {
          isInitialRead = false;
          return Future<BatteryStatus>.value(
            const BatteryStatus(level: 10, isCharging: false),
          );
        }
        return pollRead.future;
      },
    );
    addTearDown(platform.close);
    final controller = HomeController(
      platform: platform,
      batteryPollingInterval: const Duration(milliseconds: 5),
    );

    await controller.initialize();
    var notifications = 0;
    controller.addListener(() => notifications += 1);
    await _waitUntil(() => platform.batteryReads == 2);

    controller.dispose();
    pollRead.complete(const BatteryStatus(level: 99, isCharging: true));
    await Future<void>.delayed(Duration.zero);

    expect(controller.battery.level, 10);
    expect(notifications, 0);
  });

  test('openBilibili delegates to platform service', () async {
    final platform = FakePlatformGateway();
    addTearDown(platform.close);
    final controller = HomeController(platform: platform);

    await controller.openBilibili();

    expect(platform.openBilibiliCalls, 1);
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt += 1) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue);
}

class _CompletingWeatherFetcher {
  _CompletingWeatherFetcher(this.result);

  final Future<WeatherSnapshot> result;
  int calls = 0;

  Future<WeatherSnapshot> call(WeatherRequest request) {
    calls += 1;
    return result;
  }
}

class _RecordingCacheService extends CacheService {
  _RecordingCacheService(super.preferences);

  int weatherWrites = 0;

  @override
  Future<void> saveWeather(WeatherSnapshot snapshot) {
    weatherWrites += 1;
    return super.saveWeather(snapshot);
  }
}
