import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../painters/weather_icon_painter.dart';
import 'metric_cell.dart';

class TomorrowPanel extends StatelessWidget {
  const TomorrowPanel({super.key, required this.weather});

  final WeatherSnapshot? weather;

  @override
  Widget build(BuildContext context) {
    final tomorrow = weather?.tomorrow;
    final description =
        tomorrow?.description ?? '\u7b49\u5f85\u5929\u6c14\u6570\u636e';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        border: Border.all(color: const Color(0x22FFFFFF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 64,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CustomPaint(
                          painter: WeatherIconPainter(
                            tomorrow?.code ?? 61,
                            const Color(0xFF7DD3FC),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tomorrow == null
                          ? '--'
                          : '${tomorrow.low}\u00B0 / ${tomorrow.high}\u00B0',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xCCFFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
          ],
        ),
      ),
    );
  }
}
