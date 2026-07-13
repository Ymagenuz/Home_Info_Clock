import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../painters/weather_icon_painter.dart';

class TomorrowPanel extends StatelessWidget {
  const TomorrowPanel({
    super.key,
    required this.weather,
    this.compact = false,
    this.onRefresh,
  });

  final WeatherSnapshot? weather;
  final bool compact;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final tomorrow = weather?.tomorrow;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = compact || constraints.maxHeight <= 360;
        final adviceHeight = dense ? 42.0 : 48.0;
        final scrollView = CustomScrollView(
          key: const ValueKey('tomorrow-page-content'),
          physics: onRefresh == null
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, dense ? 10 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: dense ? 54 : 64,
                      child: _TomorrowSummary(tomorrow: tomorrow, dense: dense),
                    ),
                    SizedBox(height: dense ? 6 : 10),
                    SizedBox(
                      height: dense ? 99 : 112,
                      child: _TomorrowMetrics(tomorrow: tomorrow, dense: dense),
                    ),
                    SizedBox(height: dense ? 7 : 10),
                    _AdviceRow(
                      key: const ValueKey('tomorrow-advice-clothing'),
                      badge: '\u7a7f',
                      semanticLabel: '\u7a7f\u8863',
                      value: tomorrow?.clothingTip,
                      height: adviceHeight,
                    ),
                    _AdviceRow(
                      key: const ValueKey('tomorrow-advice-umbrella'),
                      badge: '\u4f1e',
                      semanticLabel: '\u96e8\u5177',
                      value: tomorrow?.umbrellaTip,
                      height: adviceHeight,
                    ),
                    _AdviceRow(
                      key: const ValueKey('tomorrow-advice-travel'),
                      badge: '\u884c',
                      semanticLabel: '\u51fa\u884c',
                      value: tomorrow?.travelTip,
                      height: adviceHeight,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        );

        final refresh = onRefresh;
        if (refresh == null) return scrollView;
        return RefreshIndicator(onRefresh: refresh, child: scrollView);
      },
    );
  }
}

class _TomorrowSummary extends StatelessWidget {
  const _TomorrowSummary({required this.tomorrow, required this.dense});

  final WeatherDay? tomorrow;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final day = tomorrow;
    final description =
        day?.description ?? '\u7b49\u5f85\u5929\u6c14\u6570\u636e';
    final highLow = day == null
        ? '--\u00B0/--\u00B0'
        : '${day.high}\u00B0/${day.low}\u00B0';
    return Row(
      children: [
        SizedBox.square(
          dimension: dense ? 44 : 52,
          child: CustomPaint(
            painter: WeatherIconPainter(
              day?.code ?? 61,
              const Color(0xFF7DD3FC),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                highLow,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xDDE8F1EC),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TomorrowMetrics extends StatelessWidget {
  const _TomorrowMetrics({required this.tomorrow, required this.dense});

  final WeatherDay? tomorrow;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final day = tomorrow;
    final gap = dense ? 7.0 : 8.0;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _CompactMetricCell(
                  key: const ValueKey('tomorrow-metric-precipitation'),
                  label: '\u964d\u6c34',
                  value: day == null ? '--' : '${day.precipitation}%',
                  icon: Icons.grain,
                  accent: const Color(0xFF68C4FF),
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _CompactMetricCell(
                  key: const ValueKey('tomorrow-metric-uv'),
                  label: '\u7d2b\u5916\u7ebf',
                  value: day == null ? '--' : '${day.uv} ${_uvLevel(day.uv)}',
                  icon: Icons.wb_sunny_outlined,
                  accent: const Color(0xFFFFD769),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _CompactMetricCell(
                  key: const ValueKey('tomorrow-metric-wind'),
                  label: '\u98ce\u901f',
                  value: day == null ? '--' : '${day.windKmh} km/h',
                  icon: Icons.air,
                  accent: const Color(0xFFA7F3D0),
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _CompactMetricCell(
                  key: const ValueKey('tomorrow-metric-temperature-range'),
                  label: '\u6e29\u5dee',
                  value: day == null
                      ? '--'
                      : '${(day.high - day.low).abs()}\u00B0',
                  icon: Icons.thermostat_outlined,
                  accent: const Color(0xFFFFB37D),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactMetricCell extends StatelessWidget {
  const _CompactMetricCell({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        border: Border.all(color: const Color(0x22FFFFFF)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xAAFFFFFF),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdviceRow extends StatelessWidget {
  const _AdviceRow({
    super.key,
    required this.badge,
    required this.semanticLabel,
    required this.value,
    required this.height,
  });

  final String badge;
  final String semanticLabel;
  final String? value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final advice = value ?? '\u5efa\u8bae\u6682\u4e0d\u53ef\u7528';
    return Semantics(
      label: '$semanticLabel\uff1a$advice',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x24FFCD5E),
              ),
              child: SizedBox.square(
                dimension: 20,
                child: Center(
                  child: Text(
                    badge,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFFFCD5E),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                advice,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _uvLevel(int uv) {
  if (uv >= 8) return '\u5f3a';
  if (uv >= 6) return '\u8f83\u5f3a';
  if (uv >= 3) return '\u4e2d';
  return '\u4f4e';
}
