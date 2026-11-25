import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/apps/providers/apps_provider.dart';
import '../../features/auth/models/server_profile.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/providers/telemetry_provider.dart';
import '../../features/storage/providers/storage_provider.dart';
import '../../features/system/providers/system_provider.dart';
import '../services/wake_on_lan_service.dart';

enum ServerConnectionStatus {
  checking,
  online,
  offline,
  shutDown,
  restarting,
  waking,
}

@immutable
class ServerConnectionState {
  final ServerConnectionStatus status;
  final DateTime? lastCheckedAt;
  final int countdownRemainingSeconds;
  final DateTime? targetWakeOrRestartAt;
  final bool isProbing;
  final String? statusDetail;
  final String? lastError;

  const ServerConnectionState({
    this.status = ServerConnectionStatus.checking,
    this.lastCheckedAt,
    this.countdownRemainingSeconds = 0,
    this.targetWakeOrRestartAt,
    this.isProbing = false,
    this.statusDetail,
    this.lastError,
  });

  ServerConnectionState copyWith({
    ServerConnectionStatus? status,
    DateTime? lastCheckedAt,
    int? countdownRemainingSeconds,
    DateTime? targetWakeOrRestartAt,
    bool clearTargetTime = false,
    bool? isProbing,
    String? statusDetail,
    bool clearStatusDetail = false,
    String? lastError,
    bool clearError = false,
  }) {
    return ServerConnectionState(
      status: status ?? this.status,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      countdownRemainingSeconds:
          countdownRemainingSeconds ?? this.countdownRemainingSeconds,
      targetWakeOrRestartAt: clearTargetTime
          ? null
          : (targetWakeOrRestartAt ?? this.targetWakeOrRestartAt),
      isProbing: isProbing ?? this.isProbing,
      statusDetail:
          clearStatusDetail ? null : (statusDetail ?? this.statusDetail),
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

typedef RouteProbeCallback = Future<ActiveRoute?> Function(ServerProfile profile);
typedef RouteToggleCallback = Future<void> Function(
    String profileId, ActiveRoute route);
typedef WolSendCallback = Future<WolSendResult> Function(ServerProfile profile);
typedef OnServerOnlineCallback = void Function();

final wakeOnLanServiceProvider = Provider<WakeOnLanService>((ref) {
  return const WakeOnLanService();
});

final serverConnectionProvider =
    StateNotifierProvider<ServerConnectionNotifier, ServerConnectionState>((ref) {
  final wolService = ref.watch(wakeOnLanServiceProvider);
  final activeServer = ref.watch(activeServerProvider);

  final notifier = ServerConnectionNotifier(
    initialServer: activeServer,
    probeRoutes: (profile) =>
        ref.read(authStateProvider.notifier).probeServerRoutes(profile),
    onRouteSelected: (profileId, route) =>
        ref.read(authStateProvider.notifier).toggleRoute(profileId, route),
    sendWolPacket: (profile) => wolService.sendMagicPacket(
      macAddress: profile.wolMacAddress ?? '',
      broadcastAddress: profile.wolBroadcastAddress,
      lanHost: profile.primaryHost,
      port: profile.wolPort,
    ),
    onServerOnline: () {
      ref.read(telemetryProvider.notifier).fetchTelemetry();
      ref.read(appsProvider.notifier).fetchApps();
      ref.read(storageProvider.notifier).fetchStorage();
      ref.read(systemProvider.notifier).fetchSystem();
    },
  );

  ref.listen<ServerProfile?>(activeServerProvider, (previous, next) {
    notifier.updateActiveServer(next, previousId: previous?.id);
  });

  return notifier;
});

class ServerConnectionNotifier extends StateNotifier<ServerConnectionState> {
  static const Duration periodicCheckInterval = Duration(minutes: 30);
  static const Duration restartWaitDuration = Duration(minutes: 3);
  static const Duration wolMaxWaitDuration = Duration(minutes: 3);
  static const Duration wolPollInterval = Duration(seconds: 5);

  final RouteProbeCallback _probeRoutes;
  final RouteToggleCallback _onRouteSelected;
  final WolSendCallback _sendWolPacket;
  final OnServerOnlineCallback _onServerOnline;

  ServerProfile? _activeServer;
  Timer? _periodicTimer;
  Timer? _countdownTimer;
  Timer? _wolPollTimer;
  ServerConnectionStatus _preWakingStatus = ServerConnectionStatus.offline;
  bool _isCheckingInFlight = false;

  ServerConnectionNotifier({
    ServerProfile? initialServer,
    required RouteProbeCallback probeRoutes,
    required RouteToggleCallback onRouteSelected,
    required WolSendCallback sendWolPacket,
    required OnServerOnlineCallback onServerOnline,
    bool autoStart = true,
  })  : _activeServer = initialServer,
        _probeRoutes = probeRoutes,
        _onRouteSelected = onRouteSelected,
        _sendWolPacket = sendWolPacket,
        _onServerOnline = onServerOnline,
        super(
          ServerConnectionState(
            status: initialServer == null
                ? ServerConnectionStatus.offline
                : ServerConnectionStatus.checking,
          ),
        ) {
    if (autoStart) {
      _startPeriodicTimer();
      if (_activeServer != null) {
        checkConnection();
      }
    }
  }

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(periodicCheckInterval, (_) {
      if (_activeServer == null) return;
      if (state.status == ServerConnectionStatus.online ||
          state.status == ServerConnectionStatus.offline) {
        checkConnection(silent: true);
      }
    });
  }

  void updateActiveServer(ServerProfile? server, {String? previousId}) {
    final prevId = previousId ?? _activeServer?.id;
    _activeServer = server;
    if (server == null) {
      _cancelTransientTimers();
      state = const ServerConnectionState(status: ServerConnectionStatus.offline);
      return;
    }

    if (prevId != server.id) {
      _cancelTransientTimers();
      checkConnection();
    }
  }

  Future<bool> checkConnection({bool silent = false}) async {
    final server = _activeServer;
    if (server == null) return false;
    if (_isCheckingInFlight) return state.status == ServerConnectionStatus.online;

    _isCheckingInFlight = true;
    final wasOnline = state.status == ServerConnectionStatus.online;

    if (!silent &&
        state.status != ServerConnectionStatus.waking &&
        state.status != ServerConnectionStatus.restarting) {
      state = state.copyWith(
        status: ServerConnectionStatus.checking,
        isProbing: true,
        clearError: true,
        statusDetail: 'Checking LAN and VPN routes...',
      );
    } else {
      state = state.copyWith(isProbing: true, clearError: true);
    }

    try {
      final reachableRoute = await _probeRoutes(server);
      final now = DateTime.now();

      if (reachableRoute != null) {
        if (reachableRoute != server.activeRoute) {
          await _onRouteSelected(server.id, reachableRoute);
        }
        _cancelTransientTimers();
        state = ServerConnectionState(
          status: ServerConnectionStatus.online,
          lastCheckedAt: now,
          isProbing: false,
          statusDetail:
              'Connected via ${reachableRoute == ActiveRoute.lan ? 'LAN' : 'VPN'}',
        );
        if (!wasOnline) {
          _onServerOnline();
        }
        return true;
      }

      // Unreachable on both routes
      if (state.status == ServerConnectionStatus.waking) {
        state = state.copyWith(
          lastCheckedAt: now,
          isProbing: false,
        );
        return false;
      }

      if (state.status == ServerConnectionStatus.shutDown) {
        state = state.copyWith(
          lastCheckedAt: now,
          isProbing: false,
          lastError: 'Server is still powered off.',
        );
        return false;
      }

      _cancelTransientTimers();
      state = ServerConnectionState(
        status: ServerConnectionStatus.offline,
        lastCheckedAt: now,
        isProbing: false,
        statusDetail: 'Unable to reach LAN or VPN host.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: wasOnline ? ServerConnectionStatus.online : ServerConnectionStatus.offline,
        lastCheckedAt: DateTime.now(),
        isProbing: false,
        lastError: e.toString(),
      );
      return false;
    } finally {
      _isCheckingInFlight = false;
    }
  }

  /// Transitions the app to the Server Off state after an in-app shutdown.
  void markShutDown() {
    _cancelTransientTimers();
    state = ServerConnectionState(
      status: ServerConnectionStatus.shutDown,
      lastCheckedAt: DateTime.now(),
      statusDetail: 'Shutdown command dispatched to TrueNAS.',
    );
  }

  /// Transitions the app to the Restarting state with a 3-minute countdown
  /// and automatically refreshes the connection when the countdown finishes.
  void markRestarting({Duration waitDuration = restartWaitDuration}) {
    _cancelTransientTimers();
    final target = DateTime.now().add(waitDuration);
    final totalSeconds = waitDuration.inSeconds.clamp(1, 3600);

    state = ServerConnectionState(
      status: ServerConnectionStatus.restarting,
      lastCheckedAt: DateTime.now(),
      countdownRemainingSeconds: totalSeconds,
      targetWakeOrRestartAt: target,
      statusDetail: 'Waiting for TrueNAS SCALE to reboot...',
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final targetAt = state.targetWakeOrRestartAt;
      if (targetAt == null || state.status != ServerConnectionStatus.restarting) {
        _countdownTimer?.cancel();
        return;
      }
      final remaining = targetAt.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _countdownTimer?.cancel();
        state = state.copyWith(
          countdownRemainingSeconds: 0,
          clearTargetTime: true,
        );
        checkConnection();
      } else {
        state = state.copyWith(countdownRemainingSeconds: remaining);
      }
    });
  }

  /// Sends a Wake-on-LAN magic packet and polls every 5s for up to 3 minutes.
  Future<WolSendResult> wakeServer({
    Duration maxWait = wolMaxWaitDuration,
    Duration pollInterval = wolPollInterval,
  }) async {
    final server = _activeServer;
    if (server == null) {
      return const WolSendResult(
        ok: false,
        errorMessage: 'No active server profile configured.',
      );
    }
    if (!server.hasWolMac) {
      return const WolSendResult(
        ok: false,
        errorMessage: 'No MAC address saved for this server.',
      );
    }

    if (state.status != ServerConnectionStatus.waking) {
      _preWakingStatus = state.status == ServerConnectionStatus.shutDown
          ? ServerConnectionStatus.shutDown
          : ServerConnectionStatus.offline;
    }

    _cancelTransientTimers();
    final result = await _sendWolPacket(server);
    if (!result.ok) {
      state = state.copyWith(lastError: result.errorMessage);
      return result;
    }

    final target = DateTime.now().add(maxWait);
    state = ServerConnectionState(
      status: ServerConnectionStatus.waking,
      lastCheckedAt: DateTime.now(),
      countdownRemainingSeconds: maxWait.inSeconds,
      targetWakeOrRestartAt: target,
      statusDetail: 'Magic packet sent to ${server.wolMacAddress}. Waiting for boot...',
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final targetAt = state.targetWakeOrRestartAt;
      if (targetAt == null || state.status != ServerConnectionStatus.waking) {
        _countdownTimer?.cancel();
        return;
      }
      final remaining = targetAt.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _cancelTransientTimers();
        state = ServerConnectionState(
          status: _preWakingStatus,
          lastCheckedAt: DateTime.now(),
          lastError: 'Server did not respond within 3 minutes after Wake-on-LAN.',
        );
      } else {
        state = state.copyWith(countdownRemainingSeconds: remaining);
      }
    });

    _wolPollTimer = Timer.periodic(pollInterval, (_) async {
      if (state.status != ServerConnectionStatus.waking) {
        _wolPollTimer?.cancel();
        return;
      }
      await checkConnection(silent: true);
    });

    return result;
  }

  void cancelWaking() {
    if (state.status != ServerConnectionStatus.waking) return;
    _cancelTransientTimers();
    state = ServerConnectionState(
      status: _preWakingStatus,
      lastCheckedAt: DateTime.now(),
    );
  }

  /// Catches up timers when the Android app returns to the foreground.
  void onAppResumed() {
    if (_activeServer == null) return;
    if (state.status == ServerConnectionStatus.restarting) {
      final targetAt = state.targetWakeOrRestartAt;
      if (targetAt != null) {
        final remaining = targetAt.difference(DateTime.now()).inSeconds;
        if (remaining <= 0) {
          _cancelTransientTimers();
          checkConnection();
        } else {
          state = state.copyWith(countdownRemainingSeconds: remaining);
        }
      }
      return;
    }

    if (state.status == ServerConnectionStatus.waking) {
      final targetAt = state.targetWakeOrRestartAt;
      if (targetAt != null && DateTime.now().isAfter(targetAt)) {
        _cancelTransientTimers();
        state = ServerConnectionState(
          status: _preWakingStatus,
          lastCheckedAt: DateTime.now(),
          lastError: 'Server did not respond within 3 minutes after Wake-on-LAN.',
        );
      } else {
        checkConnection(silent: true);
      }
      return;
    }

    final last = state.lastCheckedAt;
    if (state.status == ServerConnectionStatus.online &&
        last != null &&
        DateTime.now().difference(last) >= periodicCheckInterval) {
      checkConnection(silent: true);
    }
  }

  void _cancelTransientTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _wolPollTimer?.cancel();
    _wolPollTimer = null;
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _cancelTransientTimers();
    super.dispose();
  }
}
