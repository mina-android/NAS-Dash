import 'package:flutter_test/flutter_test.dart';
import 'package:nasdash/features/dashboard/models/telemetry_models.dart';
import 'package:nasdash/features/storage/models/storage_models.dart';
import 'package:nasdash/features/apps/models/app_model.dart';
import 'package:nasdash/features/auth/models/server_profile.dart';

void main() {
  group('TrueNAS SCALE Model Serialization Tests', () {
    test('SystemInfoData parses live TrueNAS 25.10 payload', () {
      final json = {
        'version': '25.10.7',
        'hostname': 'truenas',
        'physmem': 8315465728,
        'model': 'Intel(R) Xeon(R) CPU W3520 @ 2.67GHz',
        'cores': 8,
        'physical_cores': 4,
        'loadavg': [0.05, 0.01, 0.0],
        'uptime': '5:05:23',
        'system_product': 'HP Z400 Workstation',
        'ecc_memory': true,
      };
      final data = SystemInfoData.fromJson(json);
      expect(data.hostname, 'truenas');
      expect(data.version, '25.10.7');
      expect(data.cores, 8);
      expect(data.systemProduct, 'HP Z400 Workstation');
      expect(data.eccMemory, isTrue);
      expect(data.uptime, '5:05:23');
    });

    test('SystemInfoData strips fractional microseconds from uptime', () {
      final json = {
        'version': '25.10.7',
        'hostname': 'truenas',
        'physmem': 8315465728,
        'model': 'Intel(R) Xeon(R)',
        'cores': 8,
        'physical_cores': 4,
        'loadavg': [0.05, 0.01, 0.0],
        'uptime': '14:22:10.482917',
        'ecc_memory': false,
      };
      final data = SystemInfoData.fromJson(json);
      expect(data.uptime, '14:22:10');
    });

    test('ZfsPool parses live pools correctly', () {
      final json = {
        'id': 2,
        'name': 'data',
        'status': 'ONLINE',
        'healthy': true,
        'size': 2989297238016,
        'allocated': 989701750784,
        'free': 1999595487232,
      };
      final pool = ZfsPool.fromJson(json);
      expect(pool.name, 'data');
      expect(pool.healthy, isTrue);
      expect(pool.status, 'ONLINE');
    });

    test('TrueNasApp parses app metadata and portal correctly', () {
      final json = {
        'name': 'immich',
        'id': 'immich',
        'state': 'RUNNING',
        'version': '1.14.50',
        'human_version': 'v3.3.1_1.14.50',
        'upgrade_available': true,
        'portals': {'Web UI': 'http://192.168.1.11:30041/'},
      };
      final app = TrueNasApp.fromJson(json);
      expect(app.name, 'immich');
      expect(app.isRunning, isTrue);
      expect(app.portalUrl, 'http://192.168.1.11:30041/');
    });

    test('ServerProfile serializes and deserializes properly', () {
      final profile = ServerProfile(
        id: 'test_123',
        name: 'Home NAS',
        primaryHost: 'https://192.168.1.11',
        secondaryHost: 'https://100.102.141.91',
        authType: AuthType.apiKey,
        apiKey: 'secret_key',
        activeRoute: ActiveRoute.lan,
      );
      final json = profile.toJson();
      final recovered = ServerProfile.fromJson(json);
      expect(recovered.id, profile.id);
      expect(recovered.name, profile.name);
      expect(recovered.currentHost, 'https://192.168.1.11');
      expect(recovered.normalizedWsUrl, 'wss://192.168.1.11/api/current');
    });
  });
}
