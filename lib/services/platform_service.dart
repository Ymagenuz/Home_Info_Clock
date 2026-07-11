// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';

import '../models/battery_status.dart';

abstract interface class PlatformGateway {
  Future<void> enterKioskMode();
  Future<bool> openBilibili();
  Future<BatteryStatus> readBatteryStatus();
  Stream<BatteryStatus> watchBatteryStatus();
}

class PlatformService implements PlatformGateway {
  const PlatformService({
    MethodChannel channel = const MethodChannel('home_info_clock/platform'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<void> enterKioskMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await _channel.invokeMethod<void>('enterKioskMode');
  }

  @override
  Future<bool> openBilibili() async {
    return await _channel.invokeMethod<bool>('openBilibili') ?? false;
  }

  @override
  Future<BatteryStatus> readBatteryStatus() async {
    try {
      final battery = Battery();
      return _batteryStatusFrom(
        await battery.batteryLevel,
        await battery.batteryState,
      );
    } catch (_) {
      return const BatteryStatus.unavailable();
    }
  }

  @override
  Stream<BatteryStatus> watchBatteryStatus() async* {
    final battery = Battery();
    try {
      await for (final state in battery.onBatteryStateChanged) {
        try {
          yield _batteryStatusFrom(await battery.batteryLevel, state);
        } catch (_) {
          yield const BatteryStatus.unavailable();
        }
      }
    } catch (_) {
      yield const BatteryStatus.unavailable();
    }
  }

  BatteryStatus _batteryStatusFrom(int level, BatteryState state) {
    return BatteryStatus(
      level: level.clamp(0, 100).toInt(),
      isCharging: state == BatteryState.charging || state == BatteryState.full,
      isAvailable: true,
    );
  }
}
