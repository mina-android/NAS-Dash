import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kLandscapeLockPrefsKey = 'nas_dash_landscape_lock';
const MethodChannel _deviceChannel = MethodChannel('com.ma.nasdash/device');

class DeviceTelemetryStatus {
  final int batteryLevel;
  final bool isCharging;
  final String formattedTime;

  const DeviceTelemetryStatus({
    this.batteryLevel = 100,
    this.isCharging = false,
    this.formattedTime = '--:--',
  });

  factory DeviceTelemetryStatus.fromMap(Map<dynamic, dynamic> map, {DateTime? now}) {
    final dt = now ?? DateTime.now();
    final rawLevel = map['level'];
    final level = (rawLevel is num) ? rawLevel.toInt().clamp(0, 100) : 100;
    final charging = map['isCharging'] == true;
    return DeviceTelemetryStatus(
      batteryLevel: level,
      isCharging: charging,
      formattedTime: DateFormat('HH:mm').format(dt),
    );
  }

  DeviceTelemetryStatus copyWith({
    int? batteryLevel,
    bool? isCharging,
    String? formattedTime,
  }) {
    return DeviceTelemetryStatus(
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      formattedTime: formattedTime ?? this.formattedTime,
    );
  }
}

final landscapeModeProvider =
    StateNotifierProvider<LandscapeModeNotifier, bool>((ref) {
  return LandscapeModeNotifier();
});

class LandscapeModeNotifier extends StateNotifier<bool> {
  final bool applyPlatformEffects;

  LandscapeModeNotifier({this.applyPlatformEffects = true}) : super(false) {
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locked = prefs.getBool(kLandscapeLockPrefsKey) ?? false;
      state = locked;
      if (applyPlatformEffects && locked) {
        await _applyHardwareMode(true);
      }
    } catch (_) {}
  }

  Future<void> toggleLandscapeLock() async {
    await setLandscapeLock(!state);
  }

  Future<void> setLandscapeLock(bool locked) async {
    state = locked;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kLandscapeLockPrefsKey, locked);
    } catch (_) {}
    if (applyPlatformEffects) {
      await _applyHardwareMode(locked);
    }
  }

  Future<void> _applyHardwareMode(bool locked) async {
    try {
      if (locked) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        await _deviceChannel.invokeMethod('setKeepScreenOn', {'enable': true});
      } else {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        await _deviceChannel.invokeMethod('setKeepScreenOn', {'enable': false});
      }
    } catch (_) {}
  }
}

final deviceTelemetryProvider =
    StateNotifierProvider<DeviceTelemetryNotifier, DeviceTelemetryStatus>((ref) {
  return DeviceTelemetryNotifier();
});

class DeviceTelemetryNotifier extends StateNotifier<DeviceTelemetryStatus> {
  Timer? _timer;

  DeviceTelemetryNotifier()
      : super(DeviceTelemetryStatus(
          batteryLevel: 100,
          isCharging: false,
          formattedTime: DateFormat('HH:mm').format(DateTime.now()),
        )) {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
  }

  Future<void> refresh() async {
    final nowStr = DateFormat('HH:mm').format(DateTime.now());
    try {
      final res = await _deviceChannel.invokeMethod('getBatteryStatus');
      if (res is Map) {
        state = DeviceTelemetryStatus.fromMap(res);
        return;
      }
    } catch (_) {}
    state = state.copyWith(formattedTime: nowStr);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
