import 'package:flutter_test/flutter_test.dart';
import 'package:nasdash/features/storage/models/storage_models.dart';
import 'package:nasdash/features/dashboard/models/telemetry_models.dart';
import 'package:nasdash/features/auth/models/server_profile.dart';

void main() {
  group('RAID Topology and Usable Capacity Tests', () {
    test('ZfsPool correctly detects RAIDZ1 and calculates usable capacity with root dataset', () {
      final poolJson = {
        'id': 2,
        'name': 'data',
        'status': 'ONLINE',
        'healthy': true,
        'size': 2989297238016, // 3x 1TB raw
        'allocated': 990121967616,
        'free': 1999175270400,
        'topology': {
          'data': [
            {
              'name': 'raidz1-0',
              'type': 'RAIDZ1',
              'children': [
                {'disk': 'sdd', 'device': 'sdd1'},
                {'disk': 'sdc', 'device': 'sdc1'},
                {'disk': 'sde', 'device': 'sde1'},
              ]
            }
          ]
        }
      };

      final rootDatasetJson = {
        'id': 'data',
        'used': {'parsed': 661908307280}, // ~616.45 GiB
        'available': {'parsed': 1269623563296}, // ~1.15 TiB
      };

      final pool = ZfsPool.fromJson(poolJson, rootDataset: rootDatasetJson);

      expect(pool.raidType, 'RAIDZ1');
      expect(pool.diskCount, 3);
      expect(pool.diskNames, ['sdd', 'sdc', 'sde']);
      expect(pool.usableAllocated, 661908307280);
      expect(pool.usableFree, 1269623563296);
      expect(pool.usableSize, 661908307280 + 1269623563296);
    });

    test('ZfsPool falls back to redundancy estimation when root dataset is missing', () {
      final poolJson = {
        'id': 1,
        'name': 'backup',
        'status': 'ONLINE',
        'healthy': true,
        'size': 3000000000000,
        'allocated': 500000000000,
        'free': 2500000000000,
        'topology': {
          'data': [
            {
              'name': 'raidz1-0',
              'type': 'RAIDZ1',
              'children': [
                {'disk': 'sda'},
                {'disk': 'sdb'},
                {'disk': 'sdc'},
              ]
            }
          ]
        }
      };

      final pool = ZfsPool.fromJson(poolJson);
      expect(pool.raidType, 'RAIDZ1');
      expect(pool.usableSize, 2000000000000); // 2/3 of 3TB
    });
  });

  group('Network Interface Telemetry Tests', () {
    test('NetworkInterfaceTelemetry formats rx and tx rates accurately', () {
      final iface = NetworkInterfaceTelemetry(
        id: 'enp1s0',
        name: 'enp1s0',
        ipAddress: '192.168.1.11/24',
        linkStatus: 'UP • 1000Mb/s',
        rxKilobitsPerSec: 16000.0, // 16000 Kbps = 2,000,000 bytes/s = 1.9 MB/s
        txKilobitsPerSec: 160.0,   // 160 Kbps = 20,000 bytes/s = 19.5 KB/s
      );

      expect(iface.rxFormatted, '1.9 MB/s');
      expect(iface.txFormatted, '19.5 KB/s');
    });
  });

  group('Server Profile Tests', () {
    test('ServerProfile formats normalized HTTP and WS URLs securely', () {
      final profile = ServerProfile(
        id: 'srv-test',
        name: 'Test Server',
        primaryHost: '192.168.1.50',
        secondaryHost: 'https://100.102.1.1',
        authType: AuthType.apiKey,
        apiKey: 'test-api-key',
      );

      expect(profile.normalizedHttpUrl, 'https://192.168.1.50');
      expect(profile.normalizedWsUrl, 'wss://192.168.1.50/api/current');
      expect(profile.smbHost, '192.168.1.50');
    });
  });
}
