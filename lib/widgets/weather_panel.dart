import 'package:flutter/material.dart';

import '../models/battery_status.dart';
import '../models/weather.dart';
import '../painters/weather_icon_painter.dart';
import 'metric_cell.dart';

class WeatherPanel extends StatelessWidget {
  const WeatherPanel({super.key, required this.weather, required this.battery});

  final WeatherSnapshot? weather;
  final BatteryStatus battery;

  @override
  Widget build(BuildContext context) {
    final snapshot = weather;
    final location = snapshot?.locationLabel ?? '\u7b49\u5f85\u5b9a\u4f4d';
    final description =
        snapshot?.currentDescription ?? '\u7b49\u5f85\u5929\u6c14';
    final temp = snapshot == null ? '--' : '${snapshot.currentTemp}\u00B0';
    final weatherCode = snapshot?.currentCode ?? 0;
    final feelsLike = snapshot == null
        ? '--'
        : '${snapshot.apparentTemp}\u00B0';
    final batteryLabel = battery.isAvailable
        ? '${battery.level}%${battery.isCharging ? ' charging' : ''}'
        : '--';

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Color(0xFF7DD3FC)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
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
                        width: 76,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: CustomPaint(
                            painter: WeatherIconPainter(
                              weatherCode,
                              const Color(0xFF93E5AB),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          temp,
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                        ),
                      ),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: const Color(0xCCFFFFFF)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MetricCell(
                  label: 'Feels',
                  value: feelsLike,
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
      ),
    );
  }
}
