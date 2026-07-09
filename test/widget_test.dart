import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/app.dart';
import 'package:home_info_clock/models/app_config.dart';
import 'package:home_info_clock/services/cache_service.dart';
import 'package:home_info_clock/services/http_json_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/live_test_fakes.dart';

void main() {
  testWidgets('HomeInfoClockApp renders smoke title', (tester) async {
    await tester.pumpWidget(HomeInfoClockApp.preview());

    expect(find.text('Home Info Clock'), findsOneWidget);
  });

  testWidgets('HomeInfoClockApp accepts live dependencies', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final cache = CacheService(preferences);
    await cache.saveWeather(testWeatherSnapshot());
    final platform = FakePlatformGateway();
    addTearDown(platform.close);

    await tester.pumpWidget(
      HomeInfoClockApp(
        config: const AppConfig(),
        cache: cache,
        httpClient: const JsonHttpClient(),
        platform: platform,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cached City'), findsOneWidget);
  });
}
