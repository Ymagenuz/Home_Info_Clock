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
  });

  final WeatherSnapshot? weather;
  final WeatherStatus status;
  final bool isRefreshing;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final location =
        title ?? weather?.locationLabel ?? '\u7b49\u5f85\u5b9a\u4f4d';
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
      WeatherStatus.permissionMissing => 'Location permission needed',
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
