// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/battery_status.dart';
import '../models/weather.dart';
import '../services/cache_service.dart';
import '../services/platform_service.dart';
import 'timer_controller.dart';

typedef WeatherFetcher =
    Future<WeatherSnapshot> Function(WeatherRequest request);

class HomeController extends ChangeNotifier {
  HomeController({
    WeatherSnapshot? initialWeather,
    BatteryStatus initialBattery = const BatteryStatus.unavailable(),
    CacheService? cache,
    WeatherFetcher? fetchWeather,
    PlatformGateway? platform,
    TimerController? timerController,
    DateTime Function() now = DateTime.now,
  }) : _weather = initialWeather,
       _battery = initialBattery,
       _cache = cache,
       _fetchWeather = fetchWeather,
       _platform = platform,
       _timerController = timerController,
       _now = now;

  factory HomeController.preview() {
    return HomeController(
      initialWeather: WeatherSnapshot(
        locationLabel: '\u4e0a\u6d77 \u6d66\u4e1c',
        updatedAt: DateTime(2026, 7, 7, 9, 0),
        currentTemp: 31,
        apparentTemp: 34,
        humidity: 72,
        windKmh: 12,
        currentCode: 2,
        currentDescription: '\u591a\u4e91',
        sourceLabel: '\u9884\u89c8',
        reportTimeLabel: '09:00',
        days: const [
          WeatherDay(
            date: '2026-07-07',
            code: 2,
            description: '\u591a\u4e91',
            high: 33,
            low: 27,
          ),
          WeatherDay(
            date: '2026-07-08',
            code: 61,
            description: '\u5c0f\u96e8',
            high: 31,
            low: 26,
            precipitation: 65,
            uv: 6,
            windKmh: 18,
            clothingTip: '\u8f7b\u8584\u77ed\u8896\u5373\u53ef\u3002',
            umbrellaTip: '\u51fa\u95e8\u5e26\u4f1e\u66f4\u7a33\u3002',
            travelTip: '\u9519\u5cf0\u51fa\u884c\u66f4\u597d\u3002',
          ),
        ],
      ),
      initialBattery: const BatteryStatus(level: 86, isCharging: true),
    );
  }

  WeatherSnapshot? _weather;
  BatteryStatus _battery;
  bool _isSimpleMode = false;
  final CacheService? _cache;
  final WeatherFetcher? _fetchWeather;
  final PlatformGateway? _platform;
  final TimerController? _timerController;
  final DateTime Function() _now;
  StreamSubscription<BatteryStatus>? _batterySubscription;
  WeatherRequest? _weatherRequest;
  bool _isRefreshingWeather = false;

  WeatherSnapshot? get weather => _weather;
  BatteryStatus get battery => _battery;
  bool get isSimpleMode => _isSimpleMode;

  Future<void> initialize() async {
    final cache = _cache;
    if (cache != null) {
      final cachedWeather = cache.loadWeather();
      if (cachedWeather != null) {
        _weather = cachedWeather;
        notifyListeners();
      }
      _timerController?.restore(cache.loadTimer());
    }

    await _startBatteryUpdates();
    await _ensureWeatherRequest();

    if (_shouldRefresh(_weather)) {
      await refreshWeather(force: true);
    }
  }

  Future<void> refreshWeather({bool force = false}) async {
    if (_isRefreshingWeather) {
      return;
    }
    if (!force && !_shouldRefresh(_weather)) {
      return;
    }

    final request = await _ensureWeatherRequest();
    final fetchWeather = _fetchWeather;
    if (request == null || fetchWeather == null) {
      return;
    }

    _isRefreshingWeather = true;
    try {
      final snapshot = await fetchWeather(request);
      _weather = snapshot;
      notifyListeners();
      await _cache?.saveWeather(snapshot);
    } catch (_) {
      // Keep rendering the cached snapshot when a live refresh fails.
    } finally {
      _isRefreshingWeather = false;
    }
  }

  Future<void> openBilibili() async {
    await _platform?.openBilibili();
  }

  void toggleSimpleMode() {
    _isSimpleMode = !_isSimpleMode;
    notifyListeners();
  }

  void setWeather(WeatherSnapshot snapshot) {
    _weather = snapshot;
    notifyListeners();
  }

  void setBattery(BatteryStatus status) {
    _battery = status;
    notifyListeners();
  }

  Future<void> _startBatteryUpdates() async {
    final platform = _platform;
    if (platform == null) {
      return;
    }
    setBattery(await platform.readBatteryStatus());
    await _batterySubscription?.cancel();
    _batterySubscription = platform.watchBatteryStatus().listen(
      setBattery,
      onError: (_) => setBattery(const BatteryStatus.unavailable()),
    );
  }

  Future<WeatherRequest?> _ensureWeatherRequest() async {
    final existing = _weatherRequest;
    if (existing != null) {
      return existing;
    }
    final platform = _platform;
    if (platform == null || !await platform.requestLocationPermission()) {
      return null;
    }
    final location = await platform.resolveLocation();
    if (location == null) {
      return null;
    }
    _weatherRequest = WeatherRequest(
      latitude: location.latitude,
      longitude: location.longitude,
      locationLabel: location.label,
    );
    return _weatherRequest;
  }

  bool _shouldRefresh(WeatherSnapshot? snapshot) {
    if (snapshot == null) {
      return true;
    }
    return _now().difference(snapshot.updatedAt) > const Duration(minutes: 30);
  }

  @override
  void dispose() {
    unawaited(_batterySubscription?.cancel());
    super.dispose();
  }
}
