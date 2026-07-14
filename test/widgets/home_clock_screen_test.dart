import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/china_region.dart';
import 'package:home_info_clock/models/manual_location.dart';
import 'package:home_info_clock/models/timer_state.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/painters/analog_clock_painter.dart';
import 'package:home_info_clock/screens/home_clock_screen.dart';
import 'package:home_info_clock/services/cache_service.dart';
import 'package:home_info_clock/state/home_controller.dart';
import 'package:home_info_clock/state/timer_controller.dart';
import 'package:home_info_clock/widgets/clock_panel.dart';
import 'package:home_info_clock/widgets/weather_panel.dart';
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
    await _pumpPastHomeAnimations(tester);

    expect(
      find.byKey(const ValueKey('manual-location-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('china-province-wheel')), findsOneWidget);
    expect(find.byKey(const ValueKey('global-location-input')), findsOneWidget);
  });

  testWidgets(
    'clock tap enters the legacy simple layout and a simple-mode tap exits',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(818, 377));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: HomeClockScreen(
            homeController: HomeController.preview(),
            timerController: TimerController(),
            now: () => DateTime(2026, 7, 11, 23, 45),
          ),
        ),
      );

      await tester.tap(find.byType(ClockPanel));
      await _pumpPastHomeAnimations(tester);

      expect(find.byKey(const ValueKey('simple-mode-view')), findsOneWidget);
      expect(find.byKey(const ValueKey('simple-analog-clock')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('simple-compact-battery')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('simple-digital-time')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('simple-tomorrow-summary')),
        findsOneWidget,
      );
      expect(find.text('TOMORROW WEATHER'), findsOneWidget);
      expect(find.byTooltip('Dashboard mode'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('simple-mode-view')));
      await _pumpPastHomeAnimations(tester);

      expect(find.byKey(const ValueKey('simple-mode-view')), findsNothing);
      expect(find.byKey(const ValueKey('analog-clock-face')), findsOneWidget);
    },
  );

  testWidgets('dashboard and simple mode fade through over 320ms', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(818, 377));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final homeController = HomeController.preview();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: homeController,
          timerController: TimerController(),
          now: () => DateTime(2026, 7, 11, 23, 45),
        ),
      ),
    );

    double opacityFor(Key key) {
      final transition = find.ancestor(
        of: find.byKey(key),
        matching: find.byType(FadeTransition),
      );
      expect(transition, findsWidgets);
      return tester.widget<FadeTransition>(transition.first).opacity.value;
    }

    homeController.toggleSimpleMode();
    await tester.pump();

    expect(opacityFor(const ValueKey('full')), 1);
    expect(opacityFor(const ValueKey('simple')), 0);

    await tester.pump(const Duration(milliseconds: 80));
    expect(opacityFor(const ValueKey('full')), closeTo(0.875, 0.04));
    expect(opacityFor(const ValueKey('simple')), 0);

    await tester.pump(const Duration(milliseconds: 80));
    expect(opacityFor(const ValueKey('full')), 0);
    expect(opacityFor(const ValueKey('simple')), 0);

    await tester.pump(const Duration(milliseconds: 80));
    expect(opacityFor(const ValueKey('full')), 0);
    expect(opacityFor(const ValueKey('simple')), closeTo(0.875, 0.04));

    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey('full')), findsNothing);
    expect(opacityFor(const ValueKey('simple')), 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
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
    await _pumpPageUntilSettled(tester, rightPageView);

    expect(find.text('Bilibili'), findsOneWidget);

    await tester.drag(rightPageView, const Offset(-420, 0));
    await _pumpPageUntilSettled(tester, rightPageView);

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

    expect(find.byKey(const ValueKey('analog-clock-face')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('timer-finished-overlay')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await _showTimerPage(tester);

    expect(find.text('定时器'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('timer-finished-overlay')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('timer drag changes value while center paging stays locked', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(818, 377));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    await _showTimerPage(tester);

    final centerPages = find.byKey(const ValueKey('home-center-page-view'));
    final centerScrollable = find.descendant(
      of: centerPages,
      matching: find.byType(Scrollable),
    );
    final centerScrollState = tester.state<ScrollableState>(centerScrollable);
    final timerPageOffset = centerScrollState.position.pixels;
    expect(tester.widget<PageView>(centerPages).physics, isNull);

    final dialRect = tester.getRect(
      find.byKey(const ValueKey('timer-adjustment-dial')),
    );
    final minuteRect = tester.getRect(
      find.byKey(const ValueKey('timer-minute-select')),
    );
    final gesture = await tester.startGesture(
      minuteRect.centerRight - const Offset(2, 0),
    );
    await tester.pump();

    expect(
      tester.widget<PageView>(centerPages).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    expect(timerController.state.minutes, 15);

    await gesture.moveTo(dialRect.topCenter);
    await tester.pump();

    expect(timerController.state.minutes, 0);

    await gesture.moveTo(dialRect.centerRight);
    await tester.pump();

    expect(timerController.state.minutes, 15);
    expect(centerScrollState.position.pixels, timerPageOffset);

    await gesture.up();
    await tester.pump();

    expect(tester.widget<PageView>(centerPages).physics, isNull);

    final centerRect = tester.getRect(centerPages);
    final pageGesture = await tester.startGesture(
      centerRect.topCenter + const Offset(0, 20),
    );
    await pageGesture.moveBy(Offset(centerRect.width * 0.7, 0));
    await pageGesture.up();
    await _pumpPageUntilSettled(tester, centerPages);

    expect(
      centerScrollState.position.pixels,
      centerScrollState.position.minScrollExtent,
    );
    expect(
      find.byKey(const ValueKey('analog-clock-face')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'timer paging stays locked until every dial pointer is released',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(818, 377));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: HomeClockScreen(
            homeController: HomeController.preview(),
            timerController: TimerController(),
            now: () => DateTime(2026, 7, 9, 9),
          ),
        ),
      );
      await _showTimerPage(tester);

      final centerPages = find.byKey(const ValueKey('home-center-page-view'));
      final dialRect = tester.getRect(
        find.byKey(const ValueKey('timer-adjustment-dial')),
      );
      final minuteRect = tester.getRect(
        find.byKey(const ValueKey('timer-minute-select')),
      );
      final firstPointer = await tester.startGesture(
        minuteRect.centerRight - const Offset(2, 0),
        pointer: 1,
      );
      await tester.pump();
      final secondPointer = await tester.startGesture(
        dialRect.centerRight,
        pointer: 2,
      );
      await tester.pump();

      expect(
        tester.widget<PageView>(centerPages).physics,
        isA<NeverScrollableScrollPhysics>(),
      );

      await secondPointer.up();
      await tester.pump();
      final physicsWhileFirstPointerIsDown = tester
          .widget<PageView>(centerPages)
          .physics;

      await firstPointer.up();
      await tester.pump();

      expect(
        physicsWhileFirstPointerIsDown,
        isA<NeverScrollableScrollPhysics>(),
      );
      expect(
        tester.widget<PageView>(centerPages).physics,
        isNot(isA<NeverScrollableScrollPhysics>()),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('timer pointer up unlocks paging after state becomes running', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(818, 377));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 7, 9, 9);
    final timerController = TimerController(
      initial: const TimerState(seconds: 5),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: HomeController.preview(),
          timerController: timerController,
          now: () => now,
        ),
      ),
    );
    await _showTimerPage(tester);

    final centerPages = find.byKey(const ValueKey('home-center-page-view'));
    final secondRect = tester.getRect(
      find.byKey(const ValueKey('timer-second-select')),
    );
    final pointer = await tester.startGesture(
      secondRect.centerRight - const Offset(2, 0),
    );
    await tester.pump();

    expect(
      tester.widget<PageView>(centerPages).physics,
      isA<NeverScrollableScrollPhysics>(),
    );

    timerController.startOrClear(now);
    await tester.pump();
    expect(timerController.state.isRunning, isTrue);

    await pointer.up();
    await tester.pump();

    expect(
      tester.widget<PageView>(centerPages).physics,
      isNot(isA<NeverScrollableScrollPhysics>()),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing timer panel clears its center paging lock', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(818, 377));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final homeController = HomeController.preview();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: homeController,
          timerController: TimerController(),
          now: () => DateTime(2026, 7, 9, 9),
        ),
      ),
    );
    await _showTimerPage(tester);

    final minuteRect = tester.getRect(
      find.byKey(const ValueKey('timer-minute-select')),
    );
    final pointer = await tester.startGesture(
      minuteRect.centerRight - const Offset(2, 0),
    );
    await tester.pump();
    expect(
      tester
          .widget<PageView>(find.byKey(const ValueKey('home-center-page-view')))
          .physics,
      isA<NeverScrollableScrollPhysics>(),
    );

    homeController.toggleSimpleMode();
    await _pumpPastHomeAnimations(tester);
    homeController.toggleSimpleMode();
    await _pumpPastHomeAnimations(tester);

    final physicsAfterReturning = tester
        .widget<PageView>(find.byKey(const ValueKey('home-center-page-view')))
        .physics;

    await pointer.up();
    await tester.pump();

    expect(physicsAfterReturning, isNot(isA<NeverScrollableScrollPhysics>()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('running countdown rings remain on full and simple clock faces', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(818, 377));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 7, 9, 9);
    final homeController = HomeController.preview();
    final timerController = TimerController(
      initial: const TimerState(minutes: 1),
    )..startOrClear(now);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: homeController,
          timerController: timerController,
          now: () => now,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('clock-countdown-rings')), findsOneWidget);

    homeController.toggleSimpleMode();
    await _pumpPastHomeAnimations(tester);

    expect(
      find.byKey(const ValueKey('simple-countdown-rings')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'finished timer uses the black custom bell and repeating Java motion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1180, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final timerController = TimerController(
        initial: const TimerState(isFinished: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeClockScreen(
            homeController: HomeController.preview(),
            timerController: timerController,
            now: () => DateTime(2026, 7, 9, 9),
          ),
        ),
      );

      final overlay = find.byKey(const ValueKey('timer-finished-overlay'));
      expect(tester.widget<Material>(overlay).color, Colors.black);
      expect(find.text('时间到'), findsOneWidget);
      expect(find.text('轻触屏幕关闭'), findsOneWidget);
      expect(
        find.descendant(of: overlay, matching: find.byType(FilledButton)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: overlay,
          matching: find.byIcon(Icons.timer_outlined),
        ),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('timer-finished-bell')), findsOneWidget);

      Matrix4 motion() => tester
          .widget<Transform>(
            find.byKey(const ValueKey('timer-finished-bell-motion')),
          )
          .transform;
      double scaleOf(Matrix4 matrix) => math.sqrt(
        matrix.storage[0] * matrix.storage[0] +
            matrix.storage[1] * matrix.storage[1],
      );

      expect(motion().storage[0], closeTo(1, 0.001));
      expect(motion().storage[1], closeTo(0, 0.001));

      await tester.pump(const Duration(milliseconds: 369));
      expect(scaleOf(motion()), greaterThan(1.05));
      expect(motion().storage[1].abs(), greaterThan(0.15));

      await tester.pump(const Duration(milliseconds: 451));
      expect(motion().storage[0], closeTo(1, 0.001));
      expect(motion().storage[1], closeTo(0, 0.001));

      await tester.pump(const Duration(milliseconds: 400));
      expect(motion().storage[0], closeTo(1, 0.001));
      expect(motion().storage[1], closeTo(0, 0.001));

      await tester.pump(const Duration(milliseconds: 769));
      expect(scaleOf(motion()), greaterThan(1.05));
      expect(motion().storage[1].abs(), greaterThan(0.15));

      await tester.tap(find.byKey(const ValueKey('timer-finished-dismiss')));
      await tester.pump();
      expect(timerController.state.isFinished, isFalse);
    },
  );

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

      expect(find.byKey(const ValueKey('analog-clock-face')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('timer-finished-overlay')).hitTestable(),
        findsOneWidget,
      );

      homeController.toggleSimpleMode();
      await tester.pump(const Duration(milliseconds: 320));

      expect(find.byKey(const ValueKey('simple-analog-clock')), findsOneWidget);
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

      expect(find.text('定时器'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('timer-finished-overlay')),
        findsOneWidget,
      );

      homeController.toggleSimpleMode();
      await tester.pump(const Duration(milliseconds: 320));

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
        (node) => node.label.startsWith('切换简洁模式'),
      );
      expect(simpleMode, findsOne);

      timerController.restore(const TimerState(isFinished: true));
      await tester.pump();

      expect(simpleMode, findsNothing);
      expect(
        find.semantics.byPredicate((node) {
          final flags = node.getSemanticsData().flagsCollection;
          return node.label == '时间到' &&
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
          return node.label == '时间到' && flags.scopesRoute;
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
        (node) => node.label.startsWith('切换简洁模式'),
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

      final dismiss = find.semantics.byLabel('关闭时间到提醒');
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
      expect(find.semantics.byLabel('时间到'), findsNothing);
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

  testWidgets('clock face advances every vsync without rebuilding the panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var now = DateTime(2026, 7, 9, 9, 0, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: HomeController.preview(),
          timerController: TimerController(),
          now: () => now,
        ),
      ),
    );

    AnalogClockPainter clockPainter() {
      final customPaint = find.descendant(
        of: find.byKey(const ValueKey('analog-clock-face')),
        matching: find.byType(CustomPaint),
      );
      return tester.widget<CustomPaint>(customPaint).painter!
          as AnalogClockPainter;
    }

    final initialPainter = clockPainter();
    expect(initialPainter.currentTime, now);

    now = now.add(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(clockPainter(), same(initialPainter));
    expect(initialPainter.currentTime, now);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });

  testWidgets('one-second clock updates do not rebuild weather panels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var now = DateTime(2026, 7, 9, 9, 0, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: HomeController.preview(),
          timerController: TimerController(),
          now: () => now,
        ),
      ),
    );

    final weatherPanel = find.byType(WeatherPanel);
    final initialWidget = tester.widget<WeatherPanel>(weatherPanel);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.widget<WeatherPanel>(weatherPanel), same(initialWidget));

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });

  testWidgets('simple clock face shares the same per-frame time source', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var now = DateTime(2026, 7, 9, 9, 0, 0);
    final homeController = HomeController.preview();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: homeController,
          timerController: TimerController(),
          now: () => now,
        ),
      ),
    );
    homeController.toggleSimpleMode();
    await tester.pump(const Duration(milliseconds: 320));

    final customPaint = find.descendant(
      of: find.byKey(const ValueKey('simple-analog-clock')),
      matching: find.byType(CustomPaint),
    );
    final painter = tester.widget<CustomPaint>(customPaint).painter!
        as AnalogClockPainter;
    expect(painter.currentTime, now);

    now = now.add(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      tester.widget<CustomPaint>(customPaint).painter,
      same(painter),
    );
    expect(painter.currentTime, now);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });

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
    await _pumpPageUntilSettled(tester, centerPageView);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('timer-second-select')),
        matching: find.text('02'),
      ),
      findsOneWidget,
    );

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('timer-second-select')),
        matching: find.text('01'),
      ),
      findsOneWidget,
    );
    expect(timerController.state.isRunning, isTrue);

    now = now.add(const Duration(seconds: 59));
    await tester.pump(const Duration(seconds: 1));

    expect(timerController.state.isFinished, isTrue);
    expect(
      find.byKey(const ValueKey('timer-finished-overlay')),
      findsOneWidget,
    );
    expect(find.text('时间到'), findsOneWidget);

    homeController.toggleSimpleMode();
    await tester.pump(const Duration(milliseconds: 320));
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
      await _pumpPageUntilSettled(tester, leftPages);

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
      await _pumpPageUntilSettled(tester, leftPages);
      await tester.drag(
        find.byKey(const ValueKey('weather-current-scroll')),
        const Offset(0, 300),
      );
      await _pumpPastHomeAnimations(tester);

      expect(fetcher.calls, 1);
      expect(controller.weather, same(refreshed));
      expect(find.text('Live City'), findsOneWidget);
      expect(find.text('Fresh City'), findsNothing);
      expect(find.text('Updated 09:00'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      controller.dispose();
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

Future<void> _pumpPastHomeAnimations(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
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
    final isStable = (pixels - previousPixels).abs() < 0.01 &&
        !position.isScrollingNotifier.value;
    stableFrames = isStable ? stableFrames + 1 : 0;
    if (stableFrames >= 2) return;
    previousPixels = pixels;
  }

  fail('PageView did not settle within 120 frames');
}

Future<void> _showTimerPage(WidgetTester tester) async {
  final centerPageView = find.byKey(const ValueKey('home-center-page-view'));
  final scrollable = find.descendant(
    of: centerPageView,
    matching: find.byType(Scrollable),
  );
  final state = tester.state<ScrollableState>(scrollable);
  state.position.jumpTo(state.position.maxScrollExtent);
  await tester.pump(const Duration(milliseconds: 300));
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
