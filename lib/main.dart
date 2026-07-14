import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'models/app_config.dart';
import 'services/audio_library_service.dart';
import 'services/cache_service.dart';
import 'services/home_audio_handler.dart';
import 'services/http_json_client.dart';
import 'services/just_audio_backend.dart';
import 'services/platform_service.dart';
import 'state/audio_player_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const platform = PlatformService();
  await platform.enterKioskMode();
  final preferences = await SharedPreferences.getInstance();
  final audioHandler = await AudioService.init<HomeAudioHandler>(
    builder: () => HomeAudioHandler(backend: JustAudioBackend()),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.homepanel.clock.audio',
      androidNotificationChannelName: 'HomeInfoClock \u97f3\u9891\u64ad\u653e',
      androidNotificationChannelDescription:
          '\u540e\u53f0\u97f3\u4e50\u64ad\u653e\u63a7\u5236',
      androidStopForegroundOnPause: false,
    ),
  );
  final audioSession = await AudioSession.instance;
  await audioSession.configure(const AudioSessionConfiguration.music());
  final audioController = AudioPlayerController(
    library: const AudioLibraryService(),
    engine: audioHandler,
  );

  runApp(
    HomeInfoClockApp(
      config: AppConfig.fromEnvironment(),
      cache: CacheService(preferences),
      httpClient: const JsonHttpClient(),
      platform: platform,
      audioController: audioController,
    ),
  );
}
