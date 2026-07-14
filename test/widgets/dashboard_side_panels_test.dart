import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/screens/home_clock_screen.dart';
import 'package:home_info_clock/state/home_controller.dart';
import 'package:home_info_clock/state/timer_controller.dart';
import 'package:home_info_clock/widgets/weather_status_header.dart';

void main() {
  testWidgets('calibrated dashboard uses a compact left weather hierarchy', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(818, 377));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: HomeController.preview(),
          timerController: TimerController(),
          now: () => DateTime(2026, 7, 12, 15, 11),
        ),
      ),
    );

    final summary = find.byKey(
      const ValueKey('current-weather-compact-summary'),
    );
    expect(summary, findsOneWidget);
    expect(tester.getSize(summary).height, lessThanOrEqualTo(108));
    expect(
      find.byKey(const ValueKey('weather-metric-humidity')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('weather-metric-precipitation')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('weather-metric-uv')), findsOneWidget);
    expect(find.byKey(const ValueKey('weather-battery-strip')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('left location label fits compact column without ellipsis', (
    tester,
  ) async {
    const location = '\u6d59\u6c5f\u7701 \u676d\u5dde\u5e02 \u4f59\u676d\u533a';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 220,
              child: WeatherStatusHeader(
                weather: null,
                locationLabel: location,
                status: WeatherStatus.locationNeeded,
                isRefreshing: false,
              ),
            ),
          ),
        ),
      ),
    );

    final label = find.text(location);
    final labelWidget = tester.widget<Text>(label);
    expect(labelWidget.style?.fontSize, lessThanOrEqualTo(16));

    final inheritedStyle = DefaultTextStyle.of(
      tester.element(label),
    ).style.merge(labelWidget.style);
    final painter = TextPainter(
      text: TextSpan(text: location, style: inheritedStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: tester.getSize(label).width);
    expect(painter.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('left battery stays grouped with metrics and clear of edges', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(818, 377));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: HomeController.preview(),
          timerController: TimerController(),
        ),
      ),
    );

    final panelRect = tester.getRect(
      find.byKey(const ValueKey('weather-left-page-view')),
    );
    final metricRect = tester.getRect(
      find.byKey(const ValueKey('weather-metric-humidity')),
    );
    final batteryRect = tester.getRect(
      find.byKey(const ValueKey('weather-battery-strip')),
    );

    expect(batteryRect.top - metricRect.bottom, inInclusiveRange(14.0, 26.0));
    expect(batteryRect.left - panelRect.left, greaterThanOrEqualTo(18));
    expect(panelRect.right - batteryRect.right, greaterThanOrEqualTo(18));
    expect(panelRect.bottom - batteryRect.bottom, greaterThanOrEqualTo(36));
    expect(tester.takeException(), isNull);
  });

  testWidgets('left trend page uses compact temperature-range rows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(818, 377));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: HomeController.preview(),
          timerController: TimerController(),
        ),
      ),
    );

    final pages = find.byKey(const ValueKey('weather-left-page-view'));
    await tester.drag(pages, const Offset(-260, 0));
    await _pumpPageUntilSettled(tester, pages);

    final trend = find.byKey(const ValueKey('weather-trend-temperature-list'));
    expect(trend, findsOneWidget);
    expect(
      find.byKey(const ValueKey('weather-trend-temperature-row-0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: trend, matching: find.byType(Card)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'right tomorrow page keeps all legacy content on the first view',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(818, 377));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: HomeClockScreen(
            homeController: HomeController.preview(),
            timerController: TimerController(),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('dashboard-right-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard-right-page-indicator')),
        findsOneWidget,
      );
      expect(find.text('\u660e\u65e5\u5929\u6c14'), findsOneWidget);
      for (final key in <String>[
        'tomorrow-metric-precipitation',
        'tomorrow-metric-uv',
        'tomorrow-metric-wind',
        'tomorrow-metric-temperature-range',
        'tomorrow-advice-clothing',
        'tomorrow-advice-umbrella',
        'tomorrow-advice-travel',
      ]) {
        expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
      }

      final content = find.byKey(const ValueKey('tomorrow-page-content'));
      expect(content, findsOneWidget);
      expect(
        find.descendant(
          of: content,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('right shortcut page exposes only the Bilibili action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(818, 377));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: HomeController.preview(),
          timerController: TimerController(),
        ),
      ),
    );

    final pages = find.byKey(const ValueKey('home-right-page-view'));
    await tester.drag(pages, const Offset(-260, 0));
    await _pumpPageUntilSettled(tester, pages);

    expect(find.text('\u5feb\u6377\u5165\u53e3'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dashboard-right-page-dot-1-active')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bilibili-open-button')), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.byTooltip('Settings'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right pages return to tomorrow after twenty seconds', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(818, 377));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: HomeController.preview(),
          timerController: TimerController(),
        ),
      ),
    );

    final pages = find.byKey(const ValueKey('home-right-page-view'));
    await tester.drag(pages, const Offset(-260, 0));
    await _pumpPageUntilSettled(tester, pages);
    expect(find.text('\u5feb\u6377\u5165\u53e3'), findsOneWidget);

    await tester.pump(const Duration(seconds: 19));
    expect(find.text('\u5feb\u6377\u5165\u53e3'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('\u660e\u65e5\u5929\u6c14'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('dashboard-right-page-dot-0-active')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPageUntilSettled(
  WidgetTester tester,
  Finder pageView,
) async {
  final scrollable = find.descendant(
    of: pageView,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          (widget.axisDirection == AxisDirection.left ||
              widget.axisDirection == AxisDirection.right),
    ),
  );
  final position = tester.state<ScrollableState>(scrollable).position;
  var previousPixels = position.pixels;
  var stableFrames = 0;

  for (var frame = 0; frame < 120; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    final pixels = position.pixels;
    final isStable =
        (pixels - previousPixels).abs() < 0.01 &&
        !position.isScrollingNotifier.value;
    stableFrames = isStable ? stableFrames + 1 : 0;
    if (stableFrames >= 2) return;
    previousPixels = pixels;
  }

  fail('PageView did not settle within 120 frames');
}
