import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/timer_state.dart';
import 'package:home_info_clock/painters/timer_countdown_painter.dart';
import 'package:home_info_clock/state/timer_controller.dart';
import 'package:home_info_clock/widgets/timer_panel.dart';

void main() {
  testWidgets('TimerPanel uses the compact legacy timer composition', (
    tester,
  ) async {
    final controller = TimerController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 620,
            child: TimerPanel(
              controller: controller,
              now: DateTime(2026, 7, 9, 9),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Timer'), findsNothing);
    expect(find.text('Ready'), findsNothing);
    expect(find.text('定时器'), findsOneWidget);
    expect(find.text('时'), findsOneWidget);
    expect(find.text('分'), findsOneWidget);
    expect(find.text('秒'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);
    expect(find.byIcon(Icons.rotate_right), findsNothing);
    expect(find.byType(FilledButton), findsNothing);

    final dialRect = tester.getRect(
      find.byKey(const ValueKey('timer-adjustment-dial')),
    );
    expect(find.byKey(const ValueKey('timer-dial-paint')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('timer-dial-paint'))),
      tester.getRect(find.byKey(const ValueKey('timer-adjustment-surface'))),
    );
    for (final key in const <ValueKey<String>>[
      ValueKey('timer-hour-select'),
      ValueKey('timer-minute-select'),
      ValueKey('timer-second-select'),
    ]) {
      final unitRect = tester.getRect(find.byKey(key));
      expect(unitRect.height, closeTo(48, 0.1));
      expect(dialRect.contains(unitRect.center), isTrue);
    }

    expect(
      tester.getRect(find.byKey(const ValueKey('timer-start'))).height,
      closeTo(50, 0.1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TimerPanel fades rotation guidance around the four-degree gate',
    (tester) async {
      final controller = TimerController();

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 420,
            height: 620,
            child: TimerPanel(
              controller: controller,
              now: DateTime(2026, 7, 9, 9),
            ),
          ),
        ),
      );

      final minuteRect = tester.getRect(
        find.byKey(const ValueKey('timer-minute-select')),
      );
      final dialRect = tester.getRect(
        find.byKey(const ValueKey('timer-adjustment-dial')),
      );
      final gesture = await tester.startGesture(
        minuteRect.centerRight - const Offset(2, 0),
      );
      await tester.pump();

      Finder guidance() =>
          find.byKey(const ValueKey('timer-rotation-guidance'));
      expect(guidance(), findsOneWidget);
      expect(tester.widget<FadeTransition>(guidance()).opacity.value, 0);

      await tester.pump(const Duration(milliseconds: 90));
      expect(
        tester.widget<FadeTransition>(guidance()).opacity.value,
        closeTo(0.5, 0.03),
      );

      await gesture.moveTo(dialRect.bottomCenter);
      await tester.pump();
      expect(tester.widget<FadeTransition>(guidance()).opacity.value, 1);

      await tester.pump(const Duration(milliseconds: 90));
      expect(
        tester.widget<FadeTransition>(guidance()).opacity.value,
        closeTo(0.5, 0.03),
      );
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.widget<FadeTransition>(guidance()).opacity.value, 0);

      await gesture.up();
      await tester.pump();
    },
  );

  testWidgets('TimerPanel fades the released tick value for 180ms', (
    tester,
  ) async {
    final controller = TimerController();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 420,
          height: 620,
          child: TimerPanel(
            controller: controller,
            now: DateTime(2026, 7, 9, 9),
          ),
        ),
      ),
    );

    final minuteRect = tester.getRect(
      find.byKey(const ValueKey('timer-minute-select')),
    );
    final gesture = await tester.startGesture(
      minuteRect.centerRight - const Offset(2, 0),
    );
    await tester.pump();

    Finder tickValue() => find.byKey(const ValueKey('timer-tick-value'));
    expect(tickValue(), findsOneWidget);
    expect(tester.widget<FadeTransition>(tickValue()).opacity.value, 1);

    await gesture.up();
    await tester.pump();
    expect(tickValue(), findsOneWidget);
    expect(tester.widget<FadeTransition>(tickValue()).opacity.value, 1);

    await tester.pump(const Duration(milliseconds: 90));
    expect(
      tester.widget<FadeTransition>(tickValue()).opacity.value,
      closeTo(0.5, 0.03),
    );
    await tester.pump(const Duration(milliseconds: 90));
    expect(tickValue(), findsOneWidget);
    expect(tester.widget<FadeTransition>(tickValue()).opacity.value, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(tickValue(), findsNothing);
  });

  testWidgets('TimerPanel fades three countdown rings in over 360ms', (
    tester,
  ) async {
    final controller = TimerController(initial: const TimerState(minutes: 1));
    final now = DateTime(2026, 7, 9, 9);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 420,
          height: 620,
          child: TimerPanel(controller: controller, now: now),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('timer-countdown-rings')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('timer-start')));
    await tester.pump();

    final rings = find.byKey(const ValueKey('timer-countdown-rings'));
    expect(rings, findsOneWidget);
    expect(find.byKey(const ValueKey('timer-countdown-hours')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('timer-countdown-minutes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('timer-countdown-seconds')),
      findsOneWidget,
    );
    expect(tester.widget<FadeTransition>(rings).opacity.value, 0);

    await tester.pump(const Duration(milliseconds: 180));
    expect(
      tester.widget<FadeTransition>(rings).opacity.value,
      closeTo(0.5, 0.03),
    );
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.widget<FadeTransition>(rings).opacity.value, 1);
  });

  testWidgets('seconds countdown ring sweeps on every 16ms frame', (
    tester,
  ) async {
    final controller = TimerController(initial: const TimerState(seconds: 10));
    final now = DateTime(2026, 7, 9, 9);
    final frameTime = ValueNotifier<DateTime>(now);
    addTearDown(frameTime.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 420,
          height: 620,
          child: TimerPanel(
            controller: controller,
            now: now,
            frameTime: frameTime,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('timer-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    TimerCountdownUnitPainter secondsPainter() {
      return tester
              .widget<CustomPaint>(
                find.byKey(const ValueKey('timer-countdown-seconds')),
              )
              .painter!
          as TimerCountdownUnitPainter;
    }

    TimerCountdownUnitPainter painterFor(String unit) {
      return tester
              .widget<CustomPaint>(
                find.byKey(ValueKey('timer-countdown-$unit')),
              )
              .painter!
          as TimerCountdownUnitPainter;
    }

    final painter = secondsPainter();
    expect(painter.value, 10);
    var repaintCount = 0;
    var hourRepaintCount = 0;
    var minuteRepaintCount = 0;
    void countRepaint() => repaintCount += 1;
    void countHourRepaint() => hourRepaintCount += 1;
    void countMinuteRepaint() => minuteRepaintCount += 1;
    final hourPainter = painterFor('hours');
    final minutePainter = painterFor('minutes');
    painter.addListener(countRepaint);
    hourPainter.addListener(countHourRepaint);
    minutePainter.addListener(countMinuteRepaint);
    addTearDown(() {
      painter.removeListener(countRepaint);
      hourPainter.removeListener(countHourRepaint);
      minutePainter.removeListener(countMinuteRepaint);
    });

    frameTime.value = now.add(const Duration(milliseconds: 16));
    expect(repaintCount, 1);
    expect(hourRepaintCount, 0);
    expect(minuteRepaintCount, 0);
    await tester.pump();

    expect(secondsPainter(), same(painter));
    expect(painter.value, closeTo(9.984, 0.0001));
  });

  testWidgets('seconds ring starts full at an exact minute boundary', (
    tester,
  ) async {
    final controller = TimerController(initial: const TimerState(minutes: 1));
    final now = DateTime(2026, 7, 9, 9);
    final frameTime = ValueNotifier<DateTime>(now);
    addTearDown(frameTime.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 420,
          height: 620,
          child: TimerPanel(
            controller: controller,
            now: now,
            frameTime: frameTime,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('timer-start')));
    await tester.pump();

    TimerCountdownUnitPainter secondsPainter() {
      return tester
              .widget<CustomPaint>(
                find.byKey(const ValueKey('timer-countdown-seconds')),
              )
              .painter!
          as TimerCountdownUnitPainter;
    }

    expect(secondsPainter().value, 60);

    frameTime.value = now.add(const Duration(milliseconds: 16));
    expect(secondsPainter().value, closeTo(59.984, 0.0001));
  });

  testWidgets('TimerPanel eases a minute ring drop over 850ms', (tester) async {
    final controller = TimerController(initial: const TimerState(minutes: 2));
    final startedAt = DateTime(2026, 7, 9, 9);
    controller.startOrClear(startedAt);

    Future<void> pumpAt(DateTime now) {
      return tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 420,
            height: 620,
            child: TimerPanel(controller: controller, now: now),
          ),
        ),
      );
    }

    TimerCountdownUnitPainter minutePainter() {
      return tester
              .widget<CustomPaint>(
                find.byKey(const ValueKey('timer-countdown-minutes')),
              )
              .painter!
          as TimerCountdownUnitPainter;
    }

    await pumpAt(startedAt);
    expect(minutePainter().value, 2);

    await pumpAt(startedAt.add(const Duration(minutes: 1)));
    expect(minutePainter().value, 2);

    await tester.pump(const Duration(milliseconds: 425));
    expect(minutePainter().value, closeTo(1.75, 0.01));
    await tester.pump(const Duration(milliseconds: 425));
    expect(minutePainter().value, 1);
  });

  testWidgets('TimerPanel eases an hour ring drop over 850ms', (tester) async {
    final controller = TimerController(initial: const TimerState(hours: 2));
    final startedAt = DateTime(2026, 7, 9, 9);
    controller.startOrClear(startedAt);

    Future<void> pumpAt(DateTime now) {
      return tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 420,
            height: 620,
            child: TimerPanel(controller: controller, now: now),
          ),
        ),
      );
    }

    TimerCountdownUnitPainter hourPainter() {
      return tester
              .widget<CustomPaint>(
                find.byKey(const ValueKey('timer-countdown-hours')),
              )
              .painter!
          as TimerCountdownUnitPainter;
    }

    await pumpAt(startedAt);
    expect(hourPainter().value, 2);

    await pumpAt(startedAt.add(const Duration(hours: 1)));
    expect(hourPainter().value, 2);

    await tester.pump(const Duration(milliseconds: 425));
    expect(hourPainter().value, closeTo(1.75, 0.01));
    await tester.pump(const Duration(milliseconds: 425));
    expect(hourPainter().value, 1);
  });

  testWidgets(
    'TimerPanel begins on unit press and adjusts both rotation directions',
    (tester) async {
      final controller = TimerController();
      final now = DateTime(2026, 7, 9, 9);
      final adjustmentChanges = <bool>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 620,
              child: TimerPanel(
                controller: controller,
                now: now,
                onAdjustingChanged: adjustmentChanges.add,
              ),
            ),
          ),
        ),
      );

      final minuteRect = tester.getRect(
        find.byKey(const ValueKey('timer-minute-select')),
      );
      final gesture = await tester.startGesture(
        minuteRect.centerRight - const Offset(2, 0),
      );
      await tester.pump();

      expect(controller.state.minutes, 15);
      expect(adjustmentChanges, <bool>[true]);

      final dialRect = tester.getRect(
        find.byKey(const ValueKey('timer-adjustment-dial')),
      );
      await gesture.moveTo(dialRect.topCenter);
      await tester.pump();

      expect(controller.state.minutes, 0);

      await gesture.moveTo(dialRect.centerRight);
      await tester.pump();

      expect(controller.state.minutes, 15);

      await gesture.moveTo(dialRect.topCenter);
      await tester.pump();

      expect(controller.state.minutes, 0);

      await gesture.up();
      await tester.pump();

      expect(adjustmentChanges, <bool>[true, false]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TimerPanel keeps the zero-duration start pill disabled', (
    tester,
  ) async {
    final controller = TimerController();

    await tester.pumpWidget(
      MaterialApp(
        home: TimerPanel(controller: controller, now: DateTime(2026, 7, 9, 9)),
      ),
    );

    expect(find.text('开始'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timer-start')));
    await tester.pump();

    expect(controller.state.isRunning, isFalse);
    expect(controller.state.totalSeconds, 0);
  });

  testWidgets('TimerPanel starts a duration and clears while running', (
    tester,
  ) async {
    final controller = TimerController(initial: const TimerState(minutes: 1));
    final now = DateTime(2026, 7, 9, 9);

    await tester.pumpWidget(
      MaterialApp(
        home: TimerPanel(controller: controller, now: now),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('timer-start')));
    await tester.pump();

    expect(controller.state.isRunning, isTrue);
    expect(find.text('清零'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('timer-start')));
    await tester.pump();

    expect(controller.state.isRunning, isFalse);
    expect(controller.state.totalSeconds, 0);
    expect(find.text('开始'), findsOneWidget);
  });

  testWidgets('TimerPanel does not own the screen-global finished overlay', (
    tester,
  ) async {
    final controller = TimerController(
      initial: const TimerState(isFinished: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TimerPanel(controller: controller, now: DateTime(2026, 7, 9, 9)),
      ),
    );

    expect(find.byKey(const ValueKey('timer-finished-overlay')), findsNothing);
    expect(find.text('Finished'), findsNothing);
    expect(find.text('定时器'), findsOneWidget);
    expect(controller.state.isFinished, isTrue);
  });
}
