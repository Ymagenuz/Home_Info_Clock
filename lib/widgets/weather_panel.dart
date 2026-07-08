import 'package:flutter/material.dart';

import '../models/battery_status.dart';
import '../models/weather.dart';
import 'metric_cell.dart';

class WeatherPanel extends StatelessWidget {
  const WeatherPanel({super.key, required this.weather, required this.battery});

  final WeatherSnapshot? weather;
  final BatteryStatus battery;

  @override
  Widget build(BuildContext context) {
    final snapshot = weather;
    final location = _briefText(snapshot?.locationLabel, '绛夊緟瀹氫綅');
    final description = _briefText(snapshot?.currentDescription, '绛夊緟澶╂皵');
    final temp = snapshot == null ? '--' : '${snapshot.currentTemp}\u00B0';
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
                      const Icon(
                        Icons.cloud_queue,
                        size: 52,
                        color: Color(0xFF93E5AB),
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

String _briefText(String? value, String fallback) {
  return switch (value) {
    null => fallback,
    '\u4e0a\u6d77 \u6d66\u4e1c' => '涓婃捣 娴︿笢',
    '\u591a\u4e91' => '澶氫簯',
    '\u5c0f\u96e8' => '灏忛洦',
    _ => value,
  };
}
