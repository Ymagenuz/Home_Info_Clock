import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../state/home_controller.dart';

class WeatherStatusHeader extends StatelessWidget {
  const WeatherStatusHeader({
    super.key,
    required this.weather,
    required this.status,
    required this.isRefreshing,
    this.title,
    this.locationLabel,
    this.onLocationTap,
  });

  final WeatherSnapshot? weather;
  final WeatherStatus status;
  final bool isRefreshing;
  final String? title;
  final String? locationLabel;
  final VoidCallback? onLocationTap;

  @override
  Widget build(BuildContext context) {
    final location = title ?? locationLabel ?? weather?.locationLabel ?? '选择地点';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              title == null ? Icons.location_on_outlined : Icons.show_chart,
              color: const Color(0xFF7DD3FC),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: title == null
                  ? Semantics(
                      button: true,
                      label: '选择天气地点：$location',
                      child: InkWell(
                        key: const ValueKey('weather-location-entry'),
                        borderRadius: BorderRadius.circular(6),
                        onTap: onLocationTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                      ),
                    )
                  : Text(
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
        const SizedBox(height: 6),
        Text(
          _statusLabel(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: status == WeatherStatus.stale
                ? const Color(0xFFFFD166)
                : const Color(0xAAFFFFFF),
          ),
        ),
      ],
    );
  }

  String _statusLabel() {
    if (isRefreshing) {
      return 'Updating\u2026';
    }
    final updatedAt = weather?.updatedAt;
    return switch (status) {
      WeatherStatus.loading => 'Loading weather',
      WeatherStatus.locationNeeded => '请选择地点',
      WeatherStatus.unavailable => 'Weather unavailable',
      WeatherStatus.stale =>
        updatedAt == null
            ? 'Stale weather'
            : 'Stale \u00b7 Updated ${_formatHm(updatedAt)}',
      WeatherStatus.ready =>
        updatedAt == null ? 'Weather ready' : 'Updated ${_formatHm(updatedAt)}',
    };
  }
}

String _formatHm(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
