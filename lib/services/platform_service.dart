// ignore_for_file: prefer_initializing_formals

import 'package:flutter/services.dart';

class PlatformService {
  const PlatformService({
    MethodChannel channel = const MethodChannel('home_info_clock/platform'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<void> enterKioskMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await _channel.invokeMethod<void>('enterKioskMode');
  }

  Future<bool> openBilibili() async {
    return await _channel.invokeMethod<bool>('openBilibili') ?? false;
  }
}
