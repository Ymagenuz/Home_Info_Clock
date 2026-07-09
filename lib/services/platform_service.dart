// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

import '../models/battery_status.dart';

abstract interface class PlatformGateway {
  Future<void> enterKioskMode();
  Future<bool> openBilibili();
  Future<BatteryStatus> readBatteryStatus();
  Future<bool> requestLocationPermission();
  Future<DeviceLocation?> resolveLocation();
  Stream<BatteryStatus> watchBatteryStatus();
}

class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;
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

  @override
  Future<bool> requestLocationPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<DeviceLocation?> resolveLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final label = await _resolveLocationLabel(
        position.latitude,
        position.longitude,
      );
      return DeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        label: label,
      );
    } catch (_) {
      return null;
    }
  }

  BatteryStatus _batteryStatusFrom(int level, BatteryState state) {
    return BatteryStatus(
      level: level.clamp(0, 100).toInt(),
      isCharging: state == BatteryState.charging || state == BatteryState.full,
      isAvailable: true,
    );
  }

  Future<String> _resolveLocationLabel(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final label = _joinLabelParts([
          placemark.locality,
          placemark.subLocality,
          placemark.administrativeArea,
          placemark.country,
        ]);
        if (label.isNotEmpty) {
          return label;
        }
      }
    } catch (_) {
      // Fall back to coordinates below.
    }
    return 'Location ${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)}';
  }

  String _joinLabelParts(List<String?> values) {
    final parts = <String>[];
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty && !parts.contains(trimmed)) {
        parts.add(trimmed);
      }
      if (parts.length == 2) {
        break;
      }
    }
    return parts.join(' ');
  }
}
