import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/battery_status.dart';
import 'package:home_info_clock/models/manual_location.dart';
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

  test('initialize never requests automatic device location', () async {
    final platform = FakePlatformGateway();
    addTearDown(platform.close);
    final controller = HomeController(platform: platform);

    await controller.initialize();

    expect(controller.weather, isNull);
    expect(controller.weatherStatus.name, 'locationNeeded');
  });

  test(
    'initialize discards legacy weather without a confirmed location',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = CacheService(preferences);
      await cache.saveWeather(testWeatherSnapshot(locationLabel: 'Auto City'));
      final controller = HomeController(cache: cache);

      await controller.initialize();

      expect(controller.weather, isNull);
      expect(controller.locationLabel, '选择地点');
      expect(controller.weatherStatus, WeatherStatus.locationNeeded);
      expect(cache.loadWeather(), isNull);
    },
  );

  test(
    'initialize refreshes stale weather with the saved manual location',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = CacheService(preferences);
      const location = ManualLocation(
        label: '日本 东京',
        latitude: 35.6762,
        longitude: 139.6503,
      );
      final now = DateTime(2026, 7, 11, 10);
      await cache.saveLocation(location);
      await cache.saveWeather(
        testWeatherSnapshot(
          locationLabel: location.label,
          updatedAt: now.subtract(const Duration(hours: 1)),
        ),
      );
      final platform = FakePlatformGateway();
      addTearDown(platform.close);
      final fetcher = RecordingWeatherFetcher(
        testWeatherSnapshot(locationLabel: location.label, updatedAt: now),
      );
      final controller = HomeController(
        cache: cache,
        fetchWeather: fetcher.call,
        platform: platform,
        now: () => now,
      );

      await controller.initialize();

      expect(fetcher.calls, 1);
      expect(fetcher.lastRequest?.locationLabel, location.label);
      expect(fetcher.lastRequest?.latitude, location.latitude);
      expect(fetcher.lastRequest?.longitude, location.longitude);
    },
  );

  test('selectLocation persists and fetches the confirmed location', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final cache = CacheService(preferences);
    const location = ManualLocation(
      label: '新加坡',
      latitude: 1.3521,
      longitude: 103.8198,
    );
    final fetcher = RecordingWeatherFetcher(
      testWeatherSnapshot(locationLabel: location.label),
    );
    final controller = HomeController(cache: cache, fetchWeather: fetcher.call);

    await controller.selectLocation(location);

    expect(controller.locationLabel, location.label);
    expect(cache.loadLocation()?.label, location.label);
    expect(fetcher.calls, 1);
    expect(fetcher.lastRequest?.latitude, location.latitude);
    expect(fetcher.lastRequest?.longitude, location.longitude);
    expect(controller.weather?.locationLabel, location.label);
  });

  test(
    'selectLocation removes mismatched weather even when refresh fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = CacheService(preferences);
      final oldWeather = testWeatherSnapshot(locationLabel: 'Old City');
      await cache.saveWeather(oldWeather);
      const location = ManualLocation(
        label: 'New City',
        latitude: 1.3521,
        longitude: 103.8198,
      );
      final controller = HomeController(
        initialWeather: oldWeather,
        cache: cache,
        fetchWeather: (_) async => throw StateError('offline'),
      );

      await controller.selectLocation(location);

      expect(controller.weather, isNull);
      expect(controller.weatherStatus, WeatherStatus.unavailable);
      expect(cache.loadWeather(), isNull);
      expect(cache.loadLocation()?.label, location.label);
    },
  );

  test(
    'HomeController exposes location-needed without a saved location',
    () async {
      final platform = FakePlatformGateway();
      addTearDown(platform.close);
      final controller = HomeController(platform: platform);

      expect(controller.weatherStatus, WeatherStatus.locationNeeded);

      await controller.initialize();

      expect(controller.weatherStatus, WeatherStatus.locationNeeded);
      expect(controller.weather, isNull);
    },
  );

  test('refresh without a saved location does not fetch weather', () async {
    final platform = FakePlatformGateway();
    addTearDown(platform.close);
    final controller = HomeController(platform: platform);

    await controller.refreshWeather(force: true);

    expect(controller.weatherStatus, WeatherStatus.locationNeeded);
    expect(controller.weather, isNull);
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
    await cache.saveLocation(
      const ManualLocation(
        label: 'Cached City',
        latitude: 31.2304,
        longitude: 121.4737,
      ),
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
    await cache.saveLocation(
      const ManualLocation(
        label: 'Live City',
        latitude: 31.2304,
        longitude: 121.4737,
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

  test(
    'failed refresh retains stale cached weather and marks it stale',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = CacheService(preferences);
      final now = DateTime(2026, 7, 8, 9, 0);
      final cachedWeather = testWeatherSnapshot(
        locationLabel: 'Cached City',
        updatedAt: now.subtract(const Duration(minutes: 31)),
      );
      await cache.saveWeather(cachedWeather);
      await cache.saveLocation(
        const ManualLocation(
          label: 'Cached City',
          latitude: 31.2304,
          longitude: 121.4737,
        ),
      );
      final platform = FakePlatformGateway();
      addTearDown(platform.close);
      final controller = HomeController(
        cache: cache,
        fetchWeather: (_) async => throw StateError('offline'),
        platform: platform,
        now: () => now,
      );

      await controller.initialize();

      expect(controller.weather?.locationLabel, cachedWeather.locationLabel);
      expect(controller.weather?.updatedAt, cachedWeather.updatedAt);
      expect(controller.weatherStatus, WeatherStatus.stale);
      expect(controller.isRefreshingWeather, isFalse);
    },
  );

  test(
    'hourly weather polling refreshes stale weather and stops on dispose',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = CacheService(preferences);
      var now = DateTime(2026, 7, 8, 9);
      const location = ManualLocation(
        label: 'Scheduled City',
        latitude: 31.2304,
        longitude: 121.4737,
      );
      await cache.saveLocation(location);
      await cache.saveWeather(
        testWeatherSnapshot(locationLabel: location.label, updatedAt: now),
      );
      var fetchCalls = 0;
      WeatherRequest? lastRequest;
      final controller = HomeController(
        cache: cache,
        now: () => now,
        weatherRefreshInterval: const Duration(milliseconds: 10),
        fetchWeather: (request) async {
          fetchCalls += 1;
          lastRequest = request;
          return testWeatherSnapshot(
            locationLabel: location.label,
            updatedAt: now,
            sourceLabel: 'Network',
          );
        },
      );

      await controller.initialize();
      expect(fetchCalls, 0);

      now = now.add(const Duration(hours: 1));
      await _waitUntil(() => fetchCalls == 1);
      await _waitUntil(() => controller.weather?.updatedAt == now);

      expect(lastRequest?.locationLabel, location.label);
      expect(controller.weather?.updatedAt, now);

      controller.dispose();
      final callsAfterDispose = fetchCalls;
      now = now.add(const Duration(hours: 1));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(fetchCalls, callsAfterDispose);
    },
  );

  test('hourly weather polling reuses an in-flight refresh', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final cache = CacheService(preferences);
    var now = DateTime(2026, 7, 8, 9);
    const location = ManualLocation(
      label: 'Scheduled City',
      latitude: 31.2304,
      longitude: 121.4737,
    );
    await cache.saveLocation(location);
    await cache.saveWeather(
      testWeatherSnapshot(locationLabel: location.label, updatedAt: now),
    );
    final fetch = Completer<WeatherSnapshot>();
    final fetcher = _CompletingWeatherFetcher(fetch.future);
    final controller = HomeController(
      cache: cache,
      fetchWeather: fetcher.call,
      now: () => now,
      weatherRefreshInterval: const Duration(milliseconds: 5),
    );

    await controller.initialize();
    now = now.add(const Duration(hours: 1));
    await _waitUntil(() => fetcher.calls == 1);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fetcher.calls, 1);

    controller.dispose();
    fetch.complete(
      testWeatherSnapshot(locationLabel: location.label, updatedAt: now),
    );
    await Future<void>.delayed(Duration.zero);
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
    const location = ManualLocation(
      label: 'Saved City',
      latitude: 31.2304,
      longitude: 121.4737,
    );
    await cache.saveLocation(location);
    final fetcher = RecordingWeatherFetcher(fetchedWeather);
    final controller = HomeController(
      initialWeather: testWeatherSnapshot(
        locationLabel: location.label,
        updatedAt: DateTime(2026, 7, 8, 9, 0),
      ),
      cache: cache,
      fetchWeather: fetcher.call,
      platform: platform,
      timerController: TimerController(),
      now: () => DateTime(2026, 7, 8, 9, 0),
    );

    await controller.initialize();
    await controller.refreshWeather(force: true);

    expect(fetcher.calls, 1);
    expect(fetcher.lastRequest?.latitude, 31.2304);
    expect(controller.weather, same(fetchedWeather));
    expect(cache.loadWeather()?.locationLabel, 'Fetched City');
  });

  test(
    'concurrent selection and forced refreshes share one live request',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = _RecordingCacheService(preferences);
      final fetch = Completer<WeatherSnapshot>();
      const location = ManualLocation(
        label: 'Selected City',
        latitude: 31.2304,
        longitude: 121.4737,
      );
      final fetchedWeather = testWeatherSnapshot(
        locationLabel: 'Fetched City',
        sourceLabel: 'Network',
      );
      final fetcher = _CompletingWeatherFetcher(fetch.future);
      final controller = HomeController(
        cache: cache,
        fetchWeather: fetcher.call,
      );

      final selection = controller.selectLocation(location);
      await _waitUntil(() => fetcher.calls == 1);
      final manualRefresh = controller.refreshWeather(force: true);
      final forcedRefresh = controller.refreshWeather(force: true);
      await Future<void>.delayed(Duration.zero);

      expect(fetcher.calls, 1);
      fetch.complete(fetchedWeather);

      await Future.wait([selection, manualRefresh, forcedRefresh]);

      expect(fetcher.calls, 1);
      expect(cache.weatherWrites, 1);
      expect(controller.weather, same(fetchedWeather));
    },
  );

  test(
    'a newer location selection supersedes an in-flight weather refresh',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = CacheService(preferences);
      final fetcher = _QueuedWeatherFetcher();
      final controller = HomeController(
        cache: cache,
        fetchWeather: fetcher.call,
      );
      const oldLocation = ManualLocation(
        label: 'Old City',
        latitude: 31.2,
        longitude: 121.5,
      );
      const newLocation = ManualLocation(
        label: 'New City',
        latitude: 1.35,
        longitude: 103.82,
      );

      final firstSelection = controller.selectLocation(oldLocation);
      await _waitUntil(() => fetcher.calls == 1);
      final secondSelection = controller.selectLocation(newLocation);

      fetcher.completers[0].complete(
        testWeatherSnapshot(locationLabel: oldLocation.label),
      );
      await _waitUntil(() => fetcher.calls == 2);
      expect(fetcher.requests[1].locationLabel, newLocation.label);
      fetcher.completers[1].complete(
        testWeatherSnapshot(locationLabel: newLocation.label),
      );

      await Future.wait([firstSelection, secondSelection]);
      expect(controller.locationLabel, newLocation.label);
      expect(controller.weather?.locationLabel, newLocation.label);
      expect(cache.loadWeather()?.locationLabel, newLocation.label);
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
  });

  test('dispose during weather fetch drops the late result', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final cache = _RecordingCacheService(preferences);
    final fetch = Completer<WeatherSnapshot>();
    final fetcher = _CompletingWeatherFetcher(fetch.future);
    final controller = HomeController(cache: cache, fetchWeather: fetcher.call);

    final selection = controller.selectLocation(
      const ManualLocation(
        label: 'Selected City',
        latitude: 31.2304,
        longitude: 121.4737,
      ),
    );
    await _waitUntil(() => fetcher.calls == 1);

    controller.dispose();
    fetch.complete(testWeatherSnapshot(locationLabel: 'Late City'));

    await expectLater(selection, completes);
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

class _QueuedWeatherFetcher {
  final requests = <WeatherRequest>[];
  final completers = <Completer<WeatherSnapshot>>[];

  int get calls => requests.length;

  Future<WeatherSnapshot> call(WeatherRequest request) {
    requests.add(request);
    final completer = Completer<WeatherSnapshot>();
    completers.add(completer);
    return completer.future;
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
