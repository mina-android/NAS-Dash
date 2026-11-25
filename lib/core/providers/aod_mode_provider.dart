import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kLandscapeAodEnabledPrefsKey = 'nas_dash_landscape_aod_enabled';
const MethodChannel _aodDeviceChannel = MethodChannel('com.ma.nasdash/device');

@immutable
class AodModeState {
  final bool enabled;
  final bool isActive;
  final bool isEligible;

  const AodModeState({
    this.enabled = true,
    this.isActive = false,
    this.isEligible = false,
  });

  AodModeState copyWith({
    bool? enabled,
    bool? isActive,
    bool? isEligible,
  }) {
    return AodModeState(
      enabled: enabled ?? this.enabled,
      isActive: isActive ?? this.isActive,
      isEligible: isEligible ?? this.isEligible,
    );
  }
}

final aodModeProvider =
    StateNotifierProvider<AodModeNotifier, AodModeState>((ref) {
  return AodModeNotifier();
});

class AodModeNotifier extends StateNotifier<AodModeState> {
  static const Duration defaultInactivityTimeout = Duration(seconds: 30);
  static const double aodBrightnessFactor = 0.90;
  static const double aodMinBrightness = 0.02;
  static const double systemScreenBrightness = -1.0;

  final Duration inactivityTimeout;
  final bool applyPlatformBrightness;
  Timer? _inactivityTimer;

  AodModeNotifier({
    this.inactivityTimeout = defaultInactivityTimeout,
    this.applyPlatformBrightness = true,
  }) : super(const AodModeState()) {
    _loadSavedPreference();
  }

  Future<void> _loadSavedPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(kLandscapeAodEnabledPrefsKey);
      if (saved != null && saved != state.enabled) {
        await setEnabled(saved, persist: false);
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled, {bool persist = true}) async {
    state = state.copyWith(enabled: enabled);
    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(kLandscapeAodEnabledPrefsKey, enabled);
      } catch (_) {}
    }

    if (!enabled) {
      await _exitAod();
    } else if (state.isEligible) {
      _armInactivityTimer();
    }
  }

  void updateEligibility({
    required bool isLandscape,
    required bool isDashboardTab,
    required bool isServerOnline,
  }) {
    final eligible = isLandscape && isDashboardTab && isServerOnline;
    if (eligible == state.isEligible) return;

    state = state.copyWith(isEligible: eligible);
    if (eligible && state.enabled) {
      if (!state.isActive && _inactivityTimer == null) {
        _armInactivityTimer();
      }
    } else {
      _exitAod();
    }
  }

  /// Called on any pointer/touch activity in the app shell or AOD overlay.
  void registerUserActivity() {
    if (!state.enabled || !state.isEligible) {
      if (state.isActive) {
        _exitAod();
      }
      return;
    }

    if (state.isActive) {
      _exitAod();
    }
    _armInactivityTimer();
  }

  void onAppPaused() {
    if (state.isActive) {
      _exitAod();
    } else {
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
    }
  }

  void _armInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!state.enabled || !state.isEligible) return;
    _inactivityTimer = Timer(inactivityTimeout, _enterAod);
  }

  Future<void> _enterAod() async {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    if (!state.enabled || !state.isEligible || state.isActive) return;

    state = state.copyWith(isActive: true);
    if (applyPlatformBrightness) {
      await _dimBrightness(
        factor: aodBrightnessFactor,
        minBrightness: aodMinBrightness,
      );
    }
  }

  Future<void> _exitAod() async {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    if (!state.isActive) return;

    state = state.copyWith(isActive: false);
    if (applyPlatformBrightness) {
      await _setBrightness(systemScreenBrightness);
    }
  }

  Future<void> _dimBrightness({
    required double factor,
    required double minBrightness,
  }) async {
    try {
      await _aodDeviceChannel.invokeMethod('dimScreenBrightness', {
        'factor': factor,
        'minBrightness': minBrightness,
      });
    } catch (_) {}
  }

  Future<void> _setBrightness(double value) async {
    try {
      await _aodDeviceChannel.invokeMethod('setScreenBrightness', {
        'brightness': value,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    if (state.isActive && applyPlatformBrightness) {
      _setBrightness(systemScreenBrightness);
    }
    super.dispose();
  }
}
