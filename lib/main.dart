import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'models/app_config.dart';
import 'services/cache_service.dart';
import 'services/http_json_client.dart';
import 'services/platform_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const platform = PlatformService();
  await platform.enterKioskMode();
  final preferences = await SharedPreferences.getInstance();

  runApp(
    HomeInfoClockApp(
      config: AppConfig.fromEnvironment(),
      cache: CacheService(preferences),
      httpClient: const JsonHttpClient(),
      platform: platform,
    ),
  );
}
