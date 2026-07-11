import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/china_region.dart';
import 'package:home_info_clock/models/manual_location.dart';
import 'package:home_info_clock/models/timer_state.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/screens/home_clock_screen.dart';
import 'package:home_info_clock/services/cache_service.dart';
import 'package:home_info_clock/state/home_controller.dart';
import 'package:home_info_clock/state/timer_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/live_test_fakes.dart';

void main() {
  testWidgets('weather location text is the only entry and opens one dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = HomeController();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: controller,
          timerController: TimerController(),
          loadChinaRegions: _loadChinaRegions,
          resolveLocation: (_) async => const ManualLocation(
            label: '新加坡',
            latitude: 1.3521,
            longitude: 103.8198,
          ),
        ),
      ),
    );

    final entry = find.byKey(const ValueKey('weather-location-entry'));
    expect(entry, findsOneWidget);
    expect(find.text('选择地点'), findsOneWidget);
    expect(find.byKey(const ValueKey('manual-location-dialog')), findsNothing);

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('manual-location-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('china-province-wheel')), findsOneWidget);
    expect(find.byKey(const ValueKey('global-location-input')), findsOneWidget);
  });

  testWidgets('HomeClockScreen separates right-side pages and real text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: HomeController.preview(),
          timerController: TimerController(),
        ),
      ),
    );

    expect(find.text('\u4e0a\u6d77 \u6d66\u4e1c'), findsOneWidget);
    expect(find.text('\u5c0f\u96e8'), findsOneWidget);
    expect(find.text('Bilibili'), findsNothing);

    final rightPageView = find.byKey(const ValueKey('home-right-page-view'));
    expect(rightPageView, findsOneWidget);

    await tester.drag(rightPageView, const Offset(-420, 0));
    await tester.pumpAndSettle();

    expect(find.text('Bilibili'), findsOneWidget);

    await tester.drag(rightPageView, const Offset(-420, 0));
    await tester.pumpAndSettle();

    expect(find.text('\u9884\u7559\u9875'), findsOneWidget);
  });

  testWidgets('full dashboard fits clock and timer pages at 700x360', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: HomeController.preview(),
          timerController: TimerController(
            initial: const TimerState(isFinished: true),
          ),
          now: () => DateTime(2026, 7, 9, 9),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Home Info Clock'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('timer-finished-overlay')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await _showTimerPage(tester);

    expect(find.text('Timer'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('timer-finished-overlay')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'finished timer overlay is visible on the default Clock page and Simple Mode',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final homeController = HomeController.preview();
      final timerController = TimerController(
        initial: const TimerState(isFinished: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeClockScreen(
            homeController: homeController,
            timerController: timerController,
            now: () => DateTime(2026, 7, 9, 9),
          ),
        ),
      );

      expect(find.text('Home Info Clock'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('timer-finished-overlay')).hitTestable(),
        findsOneWidget,
      );

      homeController.toggleSimpleMode();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('simple-clock-column')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('timer-finished-overlay')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'finished timer overlay persists across pages and modes until dismissed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1180, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final homeController = HomeController.preview();
      final timerController = TimerController(
        initial: const TimerState(isFinished: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeClockScreen(
            homeController: homeController,
            timerController: timerController,
            now: () => DateTime(2026, 7, 9, 9),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('timer-finished-overlay')),
        findsOneWidget,
      );
      expect(timerController.state.isFinished, isTrue);

      await _showTimerPage(tester);

      expect(find.text('Timer'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('timer-finished-overlay')),
        findsOneWidget,
      );

      homeController.toggleSimpleMode();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('timer-finished-overlay')),
        findsOneWidget,
      );
      expect(timerController.state.isFinished, isTrue);

      await tester.tap(find.byKey(const ValueKey('timer-finished-dismiss')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('timer-finished-overlay')),
        findsNothing,
      );
      expect(timerController.state.isFinished, isFalse);
    },
  );

  testWidgets(
    'finished timer overlay scopes semantics and hides the dashboard',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final timerController = TimerController();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeClockScreen(
            homeController: HomeController.preview(),
            timerController: timerController,
            now: () => DateTime(2026, 7, 9, 9),
          ),
        ),
      );

      final simpleMode = find.semantics.byPredicate(
        (node) => node.getSemanticsData().tooltip == 'Simple mode',
      );
      expect(simpleMode, findsOne);

      timerController.restore(const TimerState(isFinished: true));
      await tester.pump();

      expect(simpleMode, findsNothing);
      expect(
        find.semantics.byPredicate((node) {
          final flags = node.getSemanticsData().flagsCollection;
          return node.label == 'Timer finished' &&
              flags.scopesRoute &&
              flags.namesRoute &&
              flags.isLiveRegion;
        }),
        findsOne,
      );

      await tester.tap(find.byKey(const ValueKey('timer-finished-dismiss')));
      await tester.pump();

      expect(
        find.semantics.byPredicate((node) {
          final flags = node.getSemanticsData().flagsCollection;
          return node.label == 'Timer finished' && flags.scopesRoute;
        }),
        findsNothing,
      );
      expect(simpleMode, findsOne);
      semantics.dispose();
    },
  );

  testWidgets(
    'finished timer traps keyboard focus and dismisses from the keyboard',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final timerController = TimerController();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeClockScreen(
            homeController: HomeController.preview(),
            timerController: timerController,
            now: () => DateTime(2026, 7, 9, 9),
          ),
        ),
      );

      final simpleMode = find.semantics.byPredicate(
        (node) => node.getSemanticsData().tooltip == 'Simple mode',
      );
      final locationEntry = find.semantics.byPredicate(
        (node) =>
            node.label.startsWith('\u9009\u62e9\u5929\u6c14\u5730\u70b9\uff1a'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        locationEntry
            .evaluate()
            .single
            .getSemanticsData()
            .flagsCollection
            .isFocused,
        ui.Tristate.isTrue,
      );

      timerController.restore(const TimerState(isFinished: true));
      await tester.pump();
      await tester.pump();

      final dismiss = find.semantics.byLabel('Dismiss');
      expect(
        dismiss.evaluate().single.getSemanticsData().flagsCollection.isFocused,
        ui.Tristate.isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        dismiss.evaluate().single.getSemanticsData().flagsCollection.isFocused,
        ui.Tristate.isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();

      expect(timerController.state.isFinished, isFalse);
      expect(
        find.byKey(const ValueKey('timer-finished-overlay')),
        findsNothing,
      );
      expect(find.semantics.byLabel('Timer finished'), findsNothing);
      expect(simpleMode, findsOne);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        locationEntry
            .evaluate()
            .single
            .getSemanticsData()
            .flagsCollection
            .isFocused,
        ui.Tristate.isTrue,
      );
      semantics.dispose();
    },
  );

  testWidgets('one periodic driver updates clocks and finishes countdown', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var now = DateTime(2026, 7, 9, 9);
    final homeController = HomeController.preview();
    final timerController = TimerController(
      initial: const TimerState(seconds: 2),
    );
    timerController.startOrClear(now);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: homeController,
          timerController: timerController,
          now: () => now,
        ),
      ),
    );

    expect(find.text('09:00'), findsOneWidget);
    final centerPageView = find.byKey(const ValueKey('home-center-page-view'));
    await tester.drag(centerPageView, const Offset(-420, 0));
    await tester.pumpAndSettle();
    expect(find.text('00:00:02'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('00:00:01'), findsOneWidget);
    expect(timerController.state.isRunning, isTrue);

    now = now.add(const Duration(seconds: 59));
    await tester.pump(const Duration(seconds: 1));

    expect(timerController.state.isFinished, isTrue);
    expect(
      find.byKey(const ValueKey('timer-finished-overlay')),
      findsOneWidget,
    );
    expect(find.text('Timer finished'), findsOneWidget);

    homeController.toggleSimpleMode();
    await tester.pumpAndSettle();
    expect(find.text('09:01'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'left weather pages show stale status, vertical trend, and pull refresh',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1180, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime(2026, 7, 9, 9);
      final stale = _weather(
        location: 'Cached City',
        updatedAt: now.subtract(const Duration(hours: 1)),
      );
      final refreshed = _weather(location: 'Fresh City', updatedAt: now);
      SharedPreferences.setMockInitialValues({});
      final cache = CacheService(await SharedPreferences.getInstance());
      await cache.saveLocation(
        const ManualLocation(
          label: 'Live City',
          latitude: 31.2,
          longitude: 121.5,
        ),
      );
      final fetcher = RecordingWeatherFetcher(refreshed);
      final controller = HomeController(
        initialWeather: _weather(location: 'Cached City', updatedAt: now),
        cache: cache,
        fetchWeather: fetcher.call,
        now: () => now,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      controller.setWeather(stale);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeClockScreen(
            homeController: controller,
            timerController: TimerController(),
            now: () => now,
          ),
        ),
      );

      expect(find.text('Stale · Updated 08:00'), findsOneWidget);
      final leftPages = find.byKey(const ValueKey('weather-left-page-view'));
      expect(leftPages, findsOneWidget);

      await tester.drag(leftPages, const Offset(-260, 0));
      await tester.pumpAndSettle();

      final trend = find.byKey(const ValueKey('weather-trend-list'));
      expect(trend, findsOneWidget);
      final trendScrollable = find.descendant(
        of: trend,
        matching: find.byType(Scrollable),
      );
      expect(
        tester.widget<Scrollable>(trendScrollable).axisDirection,
        AxisDirection.down,
      );

      await tester.drag(leftPages, const Offset(260, 0));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('weather-current-scroll')),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      expect(fetcher.calls, 1);
      expect(controller.weather, same(refreshed));
      expect(find.text('Live City'), findsOneWidget);
      expect(find.text('Fresh City'), findsNothing);
      expect(find.text('Updated 09:00'), findsOneWidget);
    },
  );
}

Future<List<ChinaRegion>> _loadChinaRegions() async {
  return const <ChinaRegion>[
    ChinaRegion(
      name: '广东省',
      code: '440000',
      children: <ChinaRegion>[
        ChinaRegion(
          name: '深圳市',
          code: '440300',
          children: <ChinaRegion>[ChinaRegion(name: '南山区', code: '440305')],
        ),
      ],
    ),
  ];
}

Future<void> _showTimerPage(WidgetTester tester) async {
  final centerPageView = find.byKey(const ValueKey('home-center-page-view'));
  final scrollable = find.descendant(
    of: centerPageView,
    matching: find.byType(Scrollable),
  );
  final state = tester.state<ScrollableState>(scrollable);
  state.position.jumpTo(state.position.maxScrollExtent);
  await tester.pumpAndSettle();
}

WeatherSnapshot _weather({
  required String location,
  required DateTime updatedAt,
}) {
  return WeatherSnapshot(
    locationLabel: location,
    updatedAt: updatedAt,
    currentTemp: 28,
    apparentTemp: 30,
    humidity: 72,
    windKmh: 12,
    currentCode: 2,
    currentDescription: 'Cloudy',
    sourceLabel: 'Test',
    reportTimeLabel: '09:00',
    days: List.generate(
      8,
      (index) => WeatherDay(
        date: '2026-07-${(9 + index).toString().padLeft(2, '0')}',
        code: index.isEven ? 2 : 61,
        description: index.isEven ? 'Cloudy' : 'Rain',
        high: 30 + index,
        low: 24,
        precipitation: index * 10,
      ),
    ),
  );
}
