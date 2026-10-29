import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/truenas_http_client.dart';
import '../models/storage_models.dart';

class StorageState {
  final List<ZfsPool> pools;
  final List<PhysicalDisk> disks;
  final List<ZfsDataset> datasets;
  final List<SnapshotTask> snapshotTasks;

  StorageState({
    required this.pools,
    required this.disks,
    required this.datasets,
    required this.snapshotTasks,
  });
}

final storageProvider =
    StateNotifierProvider<StorageNotifier, AsyncValue<StorageState>>((ref) {
  final client = ref.watch(truenasHttpClientProvider);
  return StorageNotifier(client);
});

class StorageNotifier extends StateNotifier<AsyncValue<StorageState>> {
  final TruenasHttpClient _client;

  StorageNotifier(this._client) : super(const AsyncValue.loading()) {
    fetchStorage();
  }

  Future<void> fetchStorage() async {
    try {
      // 1. Datasets first to provide root dataset stats for usable storage
      final datasetRes = await _client.get(ApiEndpoints.poolDataset);
      final rawDatasets = (datasetRes.data is List) ? (datasetRes.data as List) : [];
      final List<ZfsDataset> datasets = rawDatasets
          .map((m) => ZfsDataset.fromJson(m as Map<String, dynamic>))
          .toList();

      final Map<String, Map<String, dynamic>> rootDatasets = {};
      for (final d in rawDatasets) {
        if (d is Map<String, dynamic>) {
          final id = d['id'] as String? ?? '';
          if (!id.contains('/')) {
            rootDatasets[id] = d;
          }
        }
      }

      // 2. Pools with RAID & Usable storage resolution
      final poolRes = await _client.get(ApiEndpoints.pool);
      final List<ZfsPool> pools = (poolRes.data as List).map((m) {
        final map = m as Map<String, dynamic>;
        final poolName = map['name'] as String? ?? '';
        return ZfsPool.fromJson(map, rootDataset: rootDatasets[poolName]);
      }).toList();

      // 3. Disk Temps
      Map<String, double> diskTemps = {};
      try {
        final tempRes = await _client.post(ApiEndpoints.diskTemperatures, data: {});
        if (tempRes.data is Map) {
          (tempRes.data as Map).forEach((k, v) {
            if (v is num) diskTemps[k.toString()] = v.toDouble();
          });
        }
      } catch (_) {}

      // 4. Disks
      final diskRes = await _client.get(ApiEndpoints.disk);
      final List<PhysicalDisk> disks = (diskRes.data as List).map((m) {
        final map = m as Map<String, dynamic>;
        final name = map['name'] as String? ?? '';
        return PhysicalDisk.fromJson(map, temp: diskTemps[name]);
      }).toList();

      // 5. Snapshot tasks
      List<SnapshotTask> snapshotTasks = [];
      try {
        final snapRes = await _client.get(ApiEndpoints.poolSnapshotTask);
        if (snapRes.data is List) {
          snapshotTasks = (snapRes.data as List)
              .map((m) => SnapshotTask.fromJson(m as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}

      state = AsyncValue.data(
        StorageState(
          pools: pools,
          disks: disks,
          datasets: datasets,
          snapshotTasks: snapshotTasks,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
