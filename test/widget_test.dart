import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/app.dart';

void main() {
  testWidgets('HomeInfoClockApp renders smoke title', (tester) async {
    await tester.pumpWidget(const HomeInfoClockApp());

    expect(find.text('Home Info Clock'), findsOneWidget);
  });
}
