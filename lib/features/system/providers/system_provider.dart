import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/truenas_http_client.dart';

class SystemState {
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> smbShares;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> jobs;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> groups;

  SystemState({
    required this.alerts,
    required this.smbShares,
    this.services = const [],
    required this.jobs,
    required this.users,
    this.groups = const [],
  });
}

final systemProvider =
    StateNotifierProvider<SystemNotifier, AsyncValue<SystemState>>((ref) {
  final client = ref.watch(truenasHttpClientProvider);
  return SystemNotifier(client);
});

class SystemNotifier extends StateNotifier<AsyncValue<SystemState>> {
  final TruenasHttpClient _client;

  SystemNotifier(this._client) : super(const AsyncValue.loading()) {
    fetchSystem();
  }

  Future<void> fetchSystem() async {
    List<Map<String, dynamic>> alerts = state.valueOrNull?.alerts ?? [];
    List<Map<String, dynamic>> smbShares = state.valueOrNull?.smbShares ?? [];
    List<Map<String, dynamic>> jobs = state.valueOrNull?.jobs ?? [];
    List<Map<String, dynamic>> users = state.valueOrNull?.users ?? [];
    List<Map<String, dynamic>> groups = state.valueOrNull?.groups ?? [];

    try {
      final shareRes = await _client.get(ApiEndpoints.sharingSmb);
      if (shareRes.data is List) {
        smbShares = (shareRes.data as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    try {
      final alertRes = await _client.get(ApiEndpoints.alertList);
      if (alertRes.data is List) {
        alerts = (alertRes.data as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    try {
      final jobRes = await _client.get(ApiEndpoints.coreJobs);
      if (jobRes.data is List) {
        jobs = (jobRes.data as List).cast<Map<String, dynamic>>().take(20).toList();
      }
    } catch (_) {}

    try {
      final userRes = await _client.get(ApiEndpoints.users);
      if (userRes.data is List) {
        users = (userRes.data as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    try {
      final groupRes = await _client.get(ApiEndpoints.groups);
      if (groupRes.data is List) {
        groups = (groupRes.data as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    state = AsyncValue.data(
      SystemState(
        alerts: alerts,
        smbShares: smbShares,
        jobs: jobs,
        users: users,
        groups: groups,
      ),
    );
  }

  Future<bool> toggleShare(int id, bool enabled) async {
    try {
      await _client.put('${ApiEndpoints.sharingSmb}/id/$id', data: {'enabled': enabled});
      await fetchSystem();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reboot() async {
    try {
      await _client.post(ApiEndpoints.systemReboot);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> shutdown() async {
    try {
      await _client.post(ApiEndpoints.systemShutdown);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getFilesystemAcl(String path) async {
    try {
      final res = await _client.post(
        ApiEndpoints.filesystemGetAcl,
        data: {'path': path, 'simplified': true, 'resolve_ids': true},
      );
      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
    } catch (_) {
      try {
        final res = await _client.post(
          ApiEndpoints.filesystemGetAcl,
          data: {'path': path},
        );
        if (res.data is Map<String, dynamic>) {
          return res.data as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchPowerLogs() async {
    final results = <Map<String, dynamic>>[];

    try {
      final res = await _client.get(ApiEndpoints.coreJobs);
      if (res.data is List) {
        final all = (res.data as List).cast<Map<String, dynamic>>();
        final powerJobs = all.where((j) {
          final method = (j['method'] as String? ?? '').toLowerCase();
          return method.contains('reboot') ||
              method.contains('shutdown') ||
              method.contains('boot') ||
              method.contains('power');
        }).toList();
        results.addAll(powerJobs.reversed);
      }
    } catch (_) {}

    try {
      final sysRes = await _client.get(ApiEndpoints.systemInfo);
      if (sysRes.data is Map<String, dynamic>) {
        final info = sysRes.data as Map<String, dynamic>;
        final uptimeSeconds = (info['uptime_seconds'] as num?)?.toInt();
        if (uptimeSeconds != null && uptimeSeconds > 0) {
          final bootTime = DateTime.now().subtract(Duration(seconds: uptimeSeconds));
          results.add({
            'method': 'system.boot (Host Power-On)',
            'state': 'ONLINE',
            'time_started': {'\$date': bootTime.millisecondsSinceEpoch},
            'description': 'Current system boot session (Uptime: ${(info['uptime'] as String? ?? '').split('.').first.trim()})',
          });
        }
      }
    } catch (_) {}

    return results;
  }

  Future<List<Map<String, dynamic>>> fetchActiveJobs() async {
    try {
      final res = await _client.get(ApiEndpoints.coreJobs);
      if (res.data is List) {
        final list = (res.data as List).cast<Map<String, dynamic>>();
        return list.reversed.take(30).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> abortJob(int jobId) async {
    try {
      await _client.post(ApiEndpoints.coreJobAbort, data: {'id': jobId});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchBootState() async {
    try {
      final res = await _client.get(ApiEndpoints.bootState);
      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
