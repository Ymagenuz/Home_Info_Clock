import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/widgets/simple_mode_view.dart';
import 'package:home_info_clock/widgets/tomorrow_panel.dart';

void main() {
  testWidgets('TomorrowPanel renders clothing umbrella and travel tips', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TomorrowPanel(weather: _snapshot())),
      ),
    );

    expect(find.text('Wear a light jacket'), findsOneWidget);
    expect(find.text('Bring an umbrella'), findsOneWidget);
    expect(find.text('Allow extra travel time'), findsOneWidget);
  });

  testWidgets('Tomorrow advice exposes one concise semantic label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TomorrowPanel(weather: _snapshot())),
      ),
    );

    expect(
      find.semantics.byPredicate(
        (node) => node.label == '\u7a7f\u8863\uff1aWear a light jacket',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('TomorrowPanel pull gesture requests a weather refresh', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var refreshes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TomorrowPanel(
            weather: _snapshot(),
            onRefresh: () async => refreshes += 1,
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('tomorrow-page-content')),
      const Offset(0, 260),
    );
    await tester.pumpAndSettle();

    expect(refreshes, 1);
  });

  testWidgets('SimpleModeView uses two columns without compact overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(818, 377));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var toggles = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SimpleModeView(
            weather: _snapshot(),
            now: DateTime(2026, 7, 9, 9, 5),
            onToggleMode: () => toggles += 1,
          ),
        ),
      ),
    );

    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('2026-07-09  THU'), findsOneWidget);
    expect(find.text('TOMORROW WEATHER'), findsOneWidget);
    expect(find.byKey(const ValueKey('simple-mode-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('simple-analog-clock')), findsOneWidget);
    expect(find.byKey(const ValueKey('simple-digital-time')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('simple-tomorrow-summary')),
      findsOneWidget,
    );
    expect(find.text('29°'), findsOneWidget);
    expect(find.text('24°'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.byType(TomorrowPanel), findsNothing);
    expect(find.text('Wear a light jacket'), findsNothing);
    expect(find.text('Bring an umbrella'), findsNothing);
    expect(find.text('Allow extra travel time'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('simple-mode-view')));
    await tester.pump();

    expect(toggles, 1);
    expect(tester.takeException(), isNull);
  });
}

WeatherSnapshot _snapshot() {
  return WeatherSnapshot(
    locationLabel: 'Shanghai',
    updatedAt: DateTime(2026, 7, 9, 9),
    currentTemp: 29,
    apparentTemp: 31,
    humidity: 70,
    windKmh: 12,
    currentCode: 2,
    currentDescription: 'Cloudy',
    sourceLabel: 'Test',
    reportTimeLabel: '09:00',
    days: const [
      WeatherDay(
        date: '2026-07-09',
        code: 2,
        description: 'Cloudy',
        high: 31,
        low: 25,
      ),
      WeatherDay(
        date: '2026-07-10',
        code: 61,
        description: 'Rain',
        high: 29,
        low: 24,
        precipitation: 80,
        uv: 4,
        clothingTip: 'Wear a light jacket',
        umbrellaTip: 'Bring an umbrella',
        travelTip: 'Allow extra travel time',
      ),
    ],
  );
}
