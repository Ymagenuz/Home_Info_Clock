import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/app.dart';
import 'package:home_info_clock/models/app_config.dart';
import 'package:home_info_clock/models/manual_location.dart';
import 'package:home_info_clock/services/cache_service.dart';
import 'package:home_info_clock/services/http_json_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/live_test_fakes.dart';

void main() {
  test('production weather wiring excludes QWeather fallback', () {
    final appSource = File('lib/app.dart').readAsStringSync();

    expect(appSource, isNot(contains('qweather_weather_source.dart')));
    expect(appSource, isNot(contains('secondaryFallback:')));
  });

  test('production wiring excludes automatic device location', () {
    final platformSource = File(
      'lib/services/platform_service.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(platformSource, isNot(contains('Geolocator')));
    expect(platformSource, isNot(contains('placemarkFromCoordinates')));
    expect(
      pubspec,
      isNot(contains(RegExp(r'^\s+geolocator:', multiLine: true))),
    );
    expect(
      pubspec,
      isNot(contains(RegExp(r'^\s+geocoding:', multiLine: true))),
    );
    expect(manifest, isNot(contains('ACCESS_FINE_LOCATION')));
    expect(manifest, isNot(contains('ACCESS_COARSE_LOCATION')));
  });

  test('production app wires the existing AI API into manual location', () {
    final appSource = File('lib/app.dart').readAsStringSync();

    expect(appSource, contains('ai_location_service.dart'));
    expect(appSource, contains('AiLocationService('));
    expect(appSource, contains('china_location_service.dart'));
    expect(appSource, contains('ChinaLocationService('));
    expect(
      appSource,
      contains('resolveChinaLocation: _chinaLocationService?.resolve'),
    );
    expect(appSource, contains('resolveLocation: _aiLocationService?.resolve'));
  });

  testWidgets('HomeInfoClockApp renders the legacy clock surface', (
    tester,
  ) async {
    await tester.pumpWidget(HomeInfoClockApp.preview());

    expect(find.text('Home Info Clock'), findsNothing);
    expect(find.byKey(const ValueKey('analog-clock-face')), findsOneWidget);
  });

  testWidgets('HomeInfoClockApp accepts live dependencies', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final cache = CacheService(preferences);
    await cache.saveLocation(
      const ManualLocation(
        label: 'Cached City',
        latitude: 31.2304,
        longitude: 121.4737,
      ),
    );
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
