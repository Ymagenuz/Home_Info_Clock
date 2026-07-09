import 'package:flutter/material.dart';

import '../models/battery_status.dart';
import '../models/weather.dart';
import '../painters/weather_icon_painter.dart';
import '../state/home_controller.dart';
import 'metric_cell.dart';
import 'weather_status_header.dart';

class WeatherCurrentPage extends StatelessWidget {
  const WeatherCurrentPage({
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
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey('weather-current-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          WeatherStatusHeader(
            weather: weather,
            status: status,
            isRefreshing: isRefreshing,
          ),
          const SizedBox(height: 14),
          _CurrentWeatherCard(weather: weather),
          const SizedBox(height: 14),
          _WeatherMetrics(weather: weather, battery: battery),
        ],
      ),
    );
  }
}

class _CurrentWeatherCard extends StatelessWidget {
  const _CurrentWeatherCard({required this.weather});

  final WeatherSnapshot? weather;

  @override
  Widget build(BuildContext context) {
    final snapshot = weather;
    final description =
        snapshot?.currentDescription ?? '\u7b49\u5f85\u5929\u6c14';
    final temp = snapshot == null ? '--' : '${snapshot.currentTemp}\u00B0';
    return SizedBox(
      height: 220,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x12FFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: CustomPaint(
                  painter: WeatherIconPainter(
                    snapshot?.currentCode ?? 0,
                    const Color(0xFF93E5AB),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  temp,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xCCFFFFFF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherMetrics extends StatelessWidget {
  const _WeatherMetrics({required this.weather, required this.battery});

  final WeatherSnapshot? weather;
  final BatteryStatus battery;

  @override
  Widget build(BuildContext context) {
    final snapshot = weather;
    final batteryLabel = battery.isAvailable
        ? '${battery.level}%${battery.isCharging ? ' charging' : ''}'
        : '--';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCell(
                label: 'Feels',
                value: snapshot == null
                    ? '--'
                    : '${snapshot.apparentTemp}\u00B0',
                icon: Icons.thermostat,
                accent: const Color(0xFFFFD166),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCell(
                label: 'Humidity',
                value: snapshot == null ? '--' : '${snapshot.humidity}%',
                icon: Icons.water_drop_outlined,
                accent: const Color(0xFF7DD3FC),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricCell(
                label: 'Wind',
                value: snapshot == null ? '--' : '${snapshot.windKmh}',
                detail: 'km/h',
                icon: Icons.air,
                accent: const Color(0xFFA7F3D0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCell(
                label: 'Battery',
                value: batteryLabel,
                icon: battery.isCharging
                    ? Icons.battery_charging_full
                    : Icons.battery_5_bar,
                accent: battery.isLow
                    ? const Color(0xFFFF8A80)
                    : const Color(0xFF93E5AB),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
