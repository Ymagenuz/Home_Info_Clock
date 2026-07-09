import 'package:flutter/material.dart';

import '../models/battery_status.dart';
import '../models/weather.dart';
import '../state/home_controller.dart';
import 'weather_current_page.dart';
import 'weather_trend_page.dart';

class WeatherPanel extends StatelessWidget {
  const WeatherPanel({
    super.key,
    required this.weather,
    required this.battery,
    required this.status,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final WeatherSnapshot? weather;
  final BatteryStatus battery;
  final WeatherStatus status;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return PageView(
      key: const ValueKey('weather-left-page-view'),
      children: [
        WeatherCurrentPage(
          weather: weather,
          battery: battery,
          status: status,
          isRefreshing: isRefreshing,
          onRefresh: onRefresh,
        ),
        WeatherTrendPage(
          weather: weather,
          status: status,
          isRefreshing: isRefreshing,
          onRefresh: onRefresh,
        ),
      ],
    );
  }
}
