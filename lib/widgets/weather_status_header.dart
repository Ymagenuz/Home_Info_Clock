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
    this.locationContentWidth,
    this.onLocationTap,
  });

  final WeatherSnapshot? weather;
  final WeatherStatus status;
  final bool isRefreshing;
  final String? title;
  final String? locationLabel;
  final double? locationContentWidth;
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
                          child: _ResponsiveLocationLabel(
                            text: location,
                            maxWidth: locationContentWidth == null
                                ? null
                                : locationContentWidth! <= 32
                                ? 0
                                : locationContentWidth! - 32,
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

class _ResponsiveLocationLabel extends StatelessWidget {
  const _ResponsiveLocationLabel({
    required this.text,
    required this.maxWidth,
    required this.style,
  });

  static const double _minimumFontSize = 14;

  final String text;
  final double? maxWidth;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = DefaultTextStyle.of(context).style.merge(style);
    final preferredFontSize = resolvedStyle.fontSize ?? 16;
    final minimumFontSize = preferredFontSize < _minimumFontSize
        ? preferredFontSize
        : _minimumFontSize;

    final availableWidth = maxWidth;
    if (availableWidth == null) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: resolvedStyle,
      );
    }

    final singleLineFontSize = _singleLineFontSize(
      context: context,
      maxWidth: availableWidth,
      preferredFontSize: preferredFontSize,
      minimumFontSize: minimumFontSize,
      style: resolvedStyle,
    );

    if (singleLineFontSize != null) {
      return Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: resolvedStyle.copyWith(fontSize: singleLineFontSize),
      );
    }

    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.clip,
      style: resolvedStyle.copyWith(fontSize: minimumFontSize),
    );
  }

  double? _singleLineFontSize({
    required BuildContext context,
    required double maxWidth,
    required double preferredFontSize,
    required double minimumFontSize,
    required TextStyle style,
  }) {
    if (!maxWidth.isFinite) return preferredFontSize;

    bool fits(double fontSize) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(fontSize: fontSize),
        ),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout();
      final doesFit = painter.width <= maxWidth;
      painter.dispose();
      return doesFit;
    }

    if (fits(preferredFontSize)) return preferredFontSize;
    if (!fits(minimumFontSize)) return null;

    var lower = minimumFontSize;
    var upper = preferredFontSize;
    for (var iteration = 0; iteration < 8; iteration += 1) {
      final candidate = (lower + upper) / 2;
      if (fits(candidate)) {
        lower = candidate;
      } else {
        upper = candidate;
      }
    }
    return lower;
  }
}

String _formatHm(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
