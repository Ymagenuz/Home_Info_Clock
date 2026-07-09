import 'dart:async';

import 'package:flutter/material.dart';

import 'models/app_config.dart';
import 'screens/home_clock_screen.dart';
import 'services/ai_advice_service.dart';
import 'services/cache_service.dart';
import 'services/http_json_client.dart';
import 'services/open_meteo_weather_source.dart';
import 'services/platform_service.dart';
import 'services/qweather_weather_source.dart';
import 'services/uapi_weather_source.dart';
import 'services/weather_service.dart';
import 'state/home_controller.dart';
import 'state/timer_controller.dart';

class HomeInfoClockApp extends StatefulWidget {
  const HomeInfoClockApp({
    super.key,
    required this.config,
    required this.cache,
    required this.httpClient,
    required this.platform,
  }) : preview = false;

  const HomeInfoClockApp.preview({super.key})
    : config = null,
      cache = null,
      httpClient = null,
      platform = null,
      preview = true;

  final AppConfig? config;
  final CacheService? cache;
  final JsonHttpClient? httpClient;
  final PlatformGateway? platform;
  final bool preview;

  @override
  State<HomeInfoClockApp> createState() => _HomeInfoClockAppState();
}

class _HomeInfoClockAppState extends State<HomeInfoClockApp> {
  late final HomeController _homeController;
  late final TimerController _timerController;

  @override
  void initState() {
    super.initState();
    _timerController = TimerController();
    if (widget.preview) {
      _homeController = HomeController.preview();
      return;
    }

    final cache = widget.cache!;
    _timerController.addListener(_persistTimerState);
    _homeController = HomeController(
      cache: cache,
      fetchWeather: _buildWeatherFetcher(widget.config!, widget.httpClient!),
      platform: widget.platform!,
      timerController: _timerController,
    );
    unawaited(_homeController.initialize());
  }

  @override
  void dispose() {
    _timerController.removeListener(_persistTimerState);
    _homeController.dispose();
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Home Info Clock',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'sans',
      ),
      home: HomeClockScreen(
        homeController: _homeController,
        timerController: _timerController,
      ),
    );
  }

  WeatherFetcher _buildWeatherFetcher(
    AppConfig config,
    JsonHttpClient httpClient,
  ) {
    final weatherService = WeatherService(
      primary: UapiWeatherSource(client: httpClient, config: config),
      fallback: OpenMeteoWeatherSource(client: httpClient),
      secondaryFallback: config.hasQWeatherApiKey || config.hasQWeatherJwtConfig
          ? QWeatherWeatherSource(client: httpClient, config: config)
          : null,
    );
    final adviceService = AiAdviceService(client: httpClient, config: config);
    return (request) async {
      final snapshot = await weatherService.fetchWeather(request);
      return adviceService.applyAdvice(snapshot);
    };
  }

  void _persistTimerState() {
    final cache = widget.cache;
    if (cache == null) {
      return;
    }
    unawaited(cache.saveTimer(_timerController.state));
  }
}
