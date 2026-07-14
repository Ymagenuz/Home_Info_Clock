import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/painters/analog_clock_painter.dart';
import 'package:home_info_clock/widgets/clock_panel.dart';

void main() {
  test('AnalogClockPainter follows a per-frame time source', () {
    final initial = DateTime(2026, 7, 11, 23, 45, 30);
    final frameTime = ValueNotifier<DateTime>(initial);
    addTearDown(frameTime.dispose);
    final painter = AnalogClockPainter(initial, frameTime: frameTime);
    var repaintCount = 0;
    void countRepaint() => repaintCount += 1;
    painter.addListener(countRepaint);
    addTearDown(() => painter.removeListener(countRepaint));

    expect(painter.currentTime, initial);

    final nextFrame = initial.add(const Duration(milliseconds: 16));
    frameTime.value = nextFrame;

    expect(painter.currentTime, nextFrame);
    expect(repaintCount, 1);
  });

  testWidgets(
    'ClockPanel follows the legacy clock hierarchy and tap behavior',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(342, 392));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var toggles = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClockPanel(
              now: DateTime(2026, 7, 11, 23, 45, 30),
              onToggleMode: () => toggles += 1,
            ),
          ),
        ),
      );

      expect(find.text('Home Info Clock'), findsNothing);
      expect(find.text('Ready'), findsNothing);
      expect(find.text('2026年7月11日 星期六'), findsOneWidget);
      expect(find.text('23:45'), findsOneWidget);

      final face = find.byKey(const ValueKey('analog-clock-face'));
      expect(face, findsOneWidget);
      expect(tester.getSize(face).width, greaterThan(240));

      await tester.tap(find.byType(ClockPanel));
      await tester.pump();

      expect(toggles, 1);
    },
  );
}
