import 'package:flutter_test/flutter_test.dart';
import 'package:nasdash/core/providers/aod_mode_provider.dart';
import 'package:nasdash/core/providers/server_connection_provider.dart';
import 'package:nasdash/core/services/wake_on_lan_service.dart';
import 'package:nasdash/features/auth/models/server_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

ServerProfile _makeProfile({
  String id = 'srv_1',
  String primaryHost = 'https://192.168.1.11',
  String? secondaryHost = 'https://100.102.141.91',
  String? wolMac = 'AA:BB:CC:DD:EE:FF',
}) {
  return ServerProfile(
    id: id,
    name: 'Home NAS',
    primaryHost: primaryHost,
    secondaryHost: secondaryHost,
    authType: AuthType.apiKey,
    apiKey: 'test-key',
    wolMacAddress: wolMac,
    wolPort: 9,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WakeOnLanService', () {
    test('normalizes valid MAC formats and rejects invalid ones', () {
      expect(WakeOnLanService.normalizeMac('aa:bb:cc:dd:ee:ff'), 'AA:BB:CC:DD:EE:FF');
      expect(WakeOnLanService.normalizeMac('aa-bb-cc-dd-ee-ff'), 'AA:BB:CC:DD:EE:FF');
      expect(WakeOnLanService.normalizeMac('aabbccddeeff'), 'AA:BB:CC:DD:EE:FF');
      expect(WakeOnLanService.normalizeMac('AA:BB:CC:DD:EE'), isNull);
      expect(WakeOnLanService.normalizeMac('ZZ:BB:CC:DD:EE:FF'), isNull);
    });

    test('builds valid 102-byte magic packet', () {
      final packet = WakeOnLanService.buildMagicPacket('11-22-33-44-55-66');
      expect(packet.length, 102);
      for (var i = 0; i < 6; i++) {
        expect(packet[i], 0xFF);
      }
      const expectedMac = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66];
      for (var rep = 0; rep < 16; rep++) {
        final offset = 6 + (rep * 6);
        for (var b = 0; b < 6; b++) {
          expect(packet[offset + b], expectedMac[b]);
        }
      }
    });

    test('derives subnet broadcast from IPv4 host URLs', () {
      expect(
        WakeOnLanService.deriveSubnetBroadcast('https://192.168.1.11'),
        '192.168.1.255',
      );
      expect(
        WakeOnLanService.deriveSubnetBroadcast('10.0.0.42:443'),
        '10.0.0.255',
      );
      expect(
        WakeOnLanService.deriveSubnetBroadcast('https://nas.local'),
        isNull,
      );
    });
  });

  group('ServerProfile WoL serialization', () {
    test('serializes and deserializes WoL fields with legacy fallback', () {
      final profile = _makeProfile(wolMac: '00:11:22:33:44:55');
      final decoded = ServerProfile.fromJson(profile.toJson());
      expect(decoded.wolMacAddress, '00:11:22:33:44:55');
      expect(decoded.wolPort, 9);
      expect(decoded.hasWolMac, isTrue);

      final legacy = ServerProfile.fromMap({
        'id': 'legacy_1',
        'name': 'Legacy NAS',
        'primaryHost': 'https://192.168.1.10',
        'authType': 0,
      });
      expect(legacy.wolMacAddress, isNull);
      expect(legacy.wolPort, 9);
      expect(legacy.hasWolMac, isFalse);
    });
  });

  group('ServerConnectionNotifier', () {
    test('cold start unreachable enters offline, refresh recovers to online', () async {
      ActiveRoute? nextProbe;
      var onlineCalls = 0;

      final notifier = ServerConnectionNotifier(
        initialServer: _makeProfile(),
        probeRoutes: (_) async => nextProbe,
        onRouteSelected: (_, __) async {},
        sendWolPacket: (_) async => const WolSendResult(ok: true),
        onServerOnline: () => onlineCalls++,
        autoStart: false,
      );
      addTearDown(notifier.dispose);

      await notifier.checkConnection();
      expect(notifier.state.status, ServerConnectionStatus.offline);
      expect(onlineCalls, 0);

      nextProbe = ActiveRoute.lan;
      await notifier.checkConnection();
      expect(notifier.state.status, ServerConnectionStatus.online);
      expect(onlineCalls, 1);
    });

    test('markShutDown transitions to shutDown and wakeServer polls to online', () async {
      ActiveRoute? probeResult;
      var wolCount = 0;

      final notifier = ServerConnectionNotifier(
        initialServer: _makeProfile(),
        probeRoutes: (_) async => probeResult,
        onRouteSelected: (_, __) async {},
        sendWolPacket: (_) async {
          wolCount++;
          return const WolSendResult(ok: true);
        },
        onServerOnline: () {},
        autoStart: false,
      );
      addTearDown(notifier.dispose);

      notifier.markShutDown();
      expect(notifier.state.status, ServerConnectionStatus.shutDown);

      final res = await notifier.wakeServer(
        maxWait: const Duration(seconds: 5),
        pollInterval: const Duration(milliseconds: 50),
      );
      expect(res.ok, isTrue);
      expect(wolCount, 1);
      expect(notifier.state.status, ServerConnectionStatus.waking);

      probeResult = ActiveRoute.lan;
      await Future.delayed(const Duration(milliseconds: 120));
      expect(notifier.state.status, ServerConnectionStatus.online);
    });

    test('markRestarting counts down and auto-refreshes to online', () async {
      ActiveRoute? probeResult = ActiveRoute.lan;

      final notifier = ServerConnectionNotifier(
        initialServer: _makeProfile(),
        probeRoutes: (_) async => probeResult,
        onRouteSelected: (_, __) async {},
        sendWolPacket: (_) async => const WolSendResult(ok: true),
        onServerOnline: () {},
        autoStart: false,
      );
      addTearDown(notifier.dispose);

      notifier.markRestarting(waitDuration: const Duration(milliseconds: 1200));
      expect(notifier.state.status, ServerConnectionStatus.restarting);

      await Future.delayed(const Duration(milliseconds: 1400));
      expect(notifier.state.status, ServerConnectionStatus.online);
    });
  });

  group('AodModeNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('activates after inactivity only when eligible and wakes on user activity', () async {
      final notifier = AodModeNotifier(
        inactivityTimeout: const Duration(milliseconds: 80),
        applyPlatformBrightness: false,
      );
      addTearDown(notifier.dispose);

      notifier.updateEligibility(
        isLandscape: true,
        isDashboardTab: true,
        isServerOnline: true,
      );
      expect(notifier.state.isEligible, isTrue);
      expect(notifier.state.isActive, isFalse);

      await Future.delayed(const Duration(milliseconds: 140));
      expect(notifier.state.isActive, isTrue);

      notifier.registerUserActivity();
      expect(notifier.state.isActive, isFalse);

      // Leaving dashboard tab prevents activation
      notifier.updateEligibility(
        isLandscape: true,
        isDashboardTab: false,
        isServerOnline: true,
      );
      await Future.delayed(const Duration(milliseconds: 140));
      expect(notifier.state.isActive, isFalse);
    });
  });
}
