import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../painters/weather_icon_painter.dart';
import 'metric_cell.dart';

class TomorrowPanel extends StatelessWidget {
  const TomorrowPanel({super.key, required this.weather, this.compact = false});

  final WeatherSnapshot? weather;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tomorrow = weather?.tomorrow;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        border: Border.all(color: const Color(0x22FFFFFF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 12 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFFFFD166)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tomorrow',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 10 : 18),
            _TomorrowSummary(tomorrow: tomorrow, compact: compact),
            SizedBox(height: compact ? 10 : 16),
            Row(
              children: [
                Expanded(
                  child: MetricCell(
                    label: 'Rain',
                    value: tomorrow == null
                        ? '--'
                        : '${tomorrow.precipitation}%',
                    icon: Icons.grain,
                    accent: const Color(0xFF7DD3FC),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricCell(
                    label: 'UV',
                    value: tomorrow == null ? '--' : '${tomorrow.uv}',
                    icon: Icons.wb_sunny_outlined,
                    accent: const Color(0xFFFFD166),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 10 : 16),
            _AdviceRow(
              icon: Icons.checkroom_outlined,
              label: 'Clothing',
              value: tomorrow?.clothingTip,
            ),
            _AdviceRow(
              icon: Icons.umbrella_outlined,
              label: 'Umbrella',
              value: tomorrow?.umbrellaTip,
            ),
            _AdviceRow(
              icon: Icons.directions_transit_outlined,
              label: 'Travel',
              value: tomorrow?.travelTip,
            ),
          ],
        ),
      ),
    );
  }
}

class _TomorrowSummary extends StatelessWidget {
  const _TomorrowSummary({required this.tomorrow, required this.compact});

  final WeatherDay? tomorrow;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final day = tomorrow;
    final description =
        day?.description ?? '\u7b49\u5f85\u5929\u6c14\u6570\u636e';
    return Row(
      children: [
        SizedBox(
          width: compact ? 44 : 64,
          height: compact ? 44 : 64,
          child: CustomPaint(
            painter: WeatherIconPainter(
              day?.code ?? 61,
              const Color(0xFF7DD3FC),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                day == null ? '--' : '${day.low}\u00B0 / ${day.high}\u00B0',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xCCFFFFFF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdviceRow extends StatelessWidget {
  const _AdviceRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF93E5AB)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xAAFFFFFF),
                  ),
                ),
                Text(
                  value ?? 'Advice unavailable',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
