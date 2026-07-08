import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/screens/home_clock_screen.dart';
import 'package:home_info_clock/state/home_controller.dart';
import 'package:home_info_clock/state/timer_controller.dart';

void main() {
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
}
