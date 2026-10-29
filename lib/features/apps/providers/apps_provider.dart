import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/truenas_http_client.dart';
import '../models/app_model.dart';

final appsProvider =
    StateNotifierProvider<AppsNotifier, AsyncValue<List<TrueNasApp>>>((ref) {
  final client = ref.watch(truenasHttpClientProvider);
  return AppsNotifier(client);
});

class AppsNotifier extends StateNotifier<AsyncValue<List<TrueNasApp>>> {
  final TruenasHttpClient _client;

  AppsNotifier(this._client) : super(const AsyncValue.loading()) {
    fetchApps();
  }

  Future<void> fetchApps() async {
    try {
      final res = await _client.get(ApiEndpoints.app);
      if (res.data is List) {
        final apps = (res.data as List)
            .map((m) => TrueNasApp.fromJson(m as Map<String, dynamic>))
            .toList();
        state = AsyncValue.data(apps);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> startApp(String appName) async {
    try {
      await _client.post('${ApiEndpoints.app}/id/$appName/start');
      await fetchApps();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopApp(String appName) async {
    try {
      await _client.post('${ApiEndpoints.app}/id/$appName/stop');
      await fetchApps();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> upgradeApp(String appName) async {
    try {
      await _client.post('${ApiEndpoints.app}/id/$appName/upgrade');
      await fetchApps();
      return true;
    } catch (_) {
      return false;
    }
  }
}
