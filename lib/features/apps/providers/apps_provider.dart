import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/truenas_http_client.dart';
import '../models/app_model.dart';

class AppActionResult {
  final bool ok;
  final int? jobId;
  final String? errorMessage;

  const AppActionResult({
    required this.ok,
    this.jobId,
    this.errorMessage,
  });
}

class BatchUpgradeResult {
  final int succeeded;
  final int failed;
  final List<String> errors;

  const BatchUpgradeResult({
    required this.succeeded,
    required this.failed,
    this.errors = const [],
  });

  bool get allOk => failed == 0 && succeeded > 0;
}

class AppJobProgress {
  final String action;
  final double? percent;
  final String? description;

  const AppJobProgress({
    required this.action,
    this.percent,
    this.description,
  });
}

final activeAppJobsProvider = StateProvider<Map<String, AppJobProgress>>((ref) {
  return const {};
});

final appsProvider =
    StateNotifierProvider<AppsNotifier, AsyncValue<List<TrueNasApp>>>((ref) {
  final client = ref.watch(truenasHttpClientProvider);
  return AppsNotifier(
    client,
    onJobsChanged: (jobs) {
      ref.read(activeAppJobsProvider.notifier).state = jobs;
    },
  );
});

class AppsNotifier extends StateNotifier<AsyncValue<List<TrueNasApp>>> {
  final TruenasHttpClient _client;
  final Duration _jobPollInterval;
  final int _maxJobPolls;
  final void Function(Map<String, AppJobProgress>)? _onJobsChanged;
  final Map<String, AppJobProgress> _activeJobs = {};

  AppsNotifier(
    this._client, {
    Duration jobPollInterval = const Duration(milliseconds: 1500),
    int maxJobPolls = 120,
    void Function(Map<String, AppJobProgress>)? onJobsChanged,
  })  : _jobPollInterval = jobPollInterval,
        _maxJobPolls = maxJobPolls,
        _onJobsChanged = onJobsChanged,
        super(const AsyncValue.loading()) {
    fetchApps();
  }

  Map<String, AppJobProgress> get activeJobs => Map.unmodifiable(_activeJobs);

  void _setAppJob(String appName, AppJobProgress progress) {
    if (!mounted) return;
    _activeJobs[appName] = progress;
    _onJobsChanged?.call(Map.unmodifiable(_activeJobs));
  }

  void _clearAppJob(String appName) {
    if (!mounted) return;
    _activeJobs.remove(appName);
    _onJobsChanged?.call(Map.unmodifiable(_activeJobs));
  }

  Future<void> fetchApps() async {
    try {
      final res = await _client.get(ApiEndpoints.app);
      if (res.data is List) {
        final apps = (res.data as List)
            .whereType<Map>()
            .map((m) => TrueNasApp.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        final enriched = await _enrichUpgradeSummaries(apps);
        if (mounted) {
          state = AsyncValue.data(enriched);
        }
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  bool _needsUpgradeSummary(TrueNasApp app) {
    if (!app.upgradeAvailable) return false;
    final current = app.humanVersion.isNotEmpty ? app.humanVersion : app.version;
    final next = app.upgradeHumanVersion?.isNotEmpty == true
        ? app.upgradeHumanVersion!
        : (app.upgradeVersion ?? '');
    return next.isEmpty || next == current;
  }

  Future<List<TrueNasApp>> _enrichUpgradeSummaries(List<TrueNasApp> apps) async {
    final targets = apps.where(_needsUpgradeSummary).toList();
    if (targets.isEmpty) return apps;

    final Map<String, TrueNasApp> enrichedByName = {};
    await Future.wait(
      targets.map((app) async {
        final updated = await _fetchUpgradeSummary(app);
        if (updated != null) {
          enrichedByName[app.name] = updated;
        }
      }),
    );

    if (enrichedByName.isEmpty) return apps;
    return apps.map((app) => enrichedByName[app.name] ?? app).toList();
  }

  Future<TrueNasApp?> _fetchUpgradeSummary(TrueNasApp app) async {
    Response<dynamic>? res;
    try {
      res = await _client.post(
        ApiEndpoints.appUpgradeSummary,
        data: {'app_name': app.name},
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 422) {
        try {
          res = await _client.post(
            ApiEndpoints.appUpgradeSummary,
            data: '"${app.name}"',
          );
        } catch (_) {
          return null;
        }
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }

    if (res.data is! Map) return null;
    final summary = Map<String, dynamic>.from(res.data as Map);
    final availableVersions = summary['available_versions_for_upgrade'] as List?;
    final firstAvailable = (availableVersions != null &&
            availableVersions.isNotEmpty &&
            availableVersions.first is Map)
        ? Map<String, dynamic>.from(availableVersions.first as Map)
        : null;

    final upHuman = summary['upgrade_human_version'] as String? ??
        summary['latest_human_version'] as String? ??
        firstAvailable?['human_version'] as String?;
    final upVer = summary['upgrade_version'] as String? ??
        summary['latest_version'] as String? ??
        firstAvailable?['version'] as String?;

    if ((upHuman == null || upHuman.isEmpty) && (upVer == null || upVer.isEmpty)) {
      return null;
    }

    return app.copyWith(
      upgradeHumanVersion: (upHuman != null && upHuman.isNotEmpty) ? upHuman : null,
      upgradeVersion: (upVer != null && upVer.isNotEmpty) ? upVer : null,
    );
  }

  Future<AppActionResult> startApp(String appName) {
    return _runLifecycleAction(
      appName: appName,
      actionLabel: 'Starting',
      collectionEndpoint: ApiEndpoints.appStart,
      legacyActionSegment: 'start',
    );
  }

  Future<AppActionResult> stopApp(String appName) {
    return _runLifecycleAction(
      appName: appName,
      actionLabel: 'Stopping',
      collectionEndpoint: ApiEndpoints.appStop,
      legacyActionSegment: 'stop',
    );
  }

  Future<AppActionResult> _runLifecycleAction({
    required String appName,
    required String actionLabel,
    required String collectionEndpoint,
    required String legacyActionSegment,
  }) async {
    if (_activeJobs.containsKey(appName)) {
      return AppActionResult(
        ok: false,
        errorMessage: 'Action already in progress for $appName',
      );
    }

    _setAppJob(appName, AppJobProgress(action: actionLabel));
    try {
      final res = await _postLifecycleWithFallbacks(
        appName: appName,
        collectionEndpoint: collectionEndpoint,
        legacyActionSegment: legacyActionSegment,
      );

      final jobId = _extractJobId(res.data);
      if (jobId != null) {
        final jobResult = await _waitForJob(
          jobId,
          appName: appName,
          actionLabel: actionLabel,
        );
        await fetchApps();
        return jobResult;
      }

      await fetchApps();
      return const AppActionResult(ok: true);
    } on DioException catch (e) {
      return AppActionResult(ok: false, errorMessage: _extractDioError(e));
    } catch (e) {
      return AppActionResult(ok: false, errorMessage: e.toString());
    } finally {
      _clearAppJob(appName);
    }
  }

  Future<Response<dynamic>> _postLifecycleWithFallbacks({
    required String appName,
    required String collectionEndpoint,
    required String legacyActionSegment,
  }) async {
    try {
      return await _client.post(collectionEndpoint, data: '"$appName"');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 422) {
        try {
          return await _client.post(collectionEndpoint, data: {'app_name': appName});
        } on DioException catch (e2) {
          final status2 = e2.response?.statusCode;
          if (status2 == 404 || status2 == 405) {
            return await _client.post(
              '${ApiEndpoints.app}/id/$appName/$legacyActionSegment',
              data: <String, dynamic>{},
            );
          }
          rethrow;
        }
      }
      if (status == 404 || status == 405) {
        return await _client.post(
          '${ApiEndpoints.app}/id/$appName/$legacyActionSegment',
          data: <String, dynamic>{},
        );
      }
      rethrow;
    }
  }

  Future<AppActionResult> upgradeApp(String appName) async {
    if (_activeJobs.containsKey(appName)) {
      return AppActionResult(
        ok: false,
        errorMessage: 'Upgrade already in progress for $appName',
      );
    }

    _setAppJob(appName, const AppJobProgress(action: 'Upgrading'));
    try {
      final res = await _postUpgradeWithFallbacks(appName);
      final jobId = _extractJobId(res.data);
      if (jobId != null) {
        final jobResult = await _waitForJob(
          jobId,
          appName: appName,
          actionLabel: 'Upgrading',
        );
        await fetchApps();
        return jobResult;
      }

      await fetchApps();
      return const AppActionResult(ok: true);
    } on DioException catch (e) {
      return AppActionResult(ok: false, errorMessage: _extractDioError(e));
    } catch (e) {
      return AppActionResult(ok: false, errorMessage: e.toString());
    } finally {
      _clearAppJob(appName);
    }
  }

  Future<Response<dynamic>> _postUpgradeWithFallbacks(String appName) async {
    try {
      return await _client.post(
        ApiEndpoints.appUpgrade,
        data: {
          'app_name': appName,
          'options': <String, dynamic>{},
        },
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 422) {
        try {
          return await _client.post(
            ApiEndpoints.appUpgrade,
            data: {'app_name': appName},
          );
        } on DioException catch (e2) {
          final status2 = e2.response?.statusCode;
          if (status2 == 404 || status2 == 405) {
            return await _client.post(
              '${ApiEndpoints.app}/id/$appName/upgrade',
              data: <String, dynamic>{},
            );
          }
          rethrow;
        }
      }
      if (status == 404 || status == 405) {
        return await _client.post(
          '${ApiEndpoints.app}/id/$appName/upgrade',
          data: <String, dynamic>{},
        );
      }
      rethrow;
    }
  }

  Future<BatchUpgradeResult> upgradeAllApps(List<String> appNames) async {
    int succeeded = 0;
    int failed = 0;
    final errors = <String>[];

    for (final name in appNames) {
      final result = await upgradeApp(name);
      if (result.ok) {
        succeeded++;
      } else {
        failed++;
        errors.add('$name: ${result.errorMessage ?? 'Upgrade failed'}');
      }
    }

    return BatchUpgradeResult(
      succeeded: succeeded,
      failed: failed,
      errors: errors,
    );
  }

  int? _extractJobId(dynamic data) {
    if (data is int) return data;
    if (data is num) return data.toInt();
    if (data is String) return int.tryParse(data.trim());
    if (data is Map) {
      final raw = data['id'] ?? data['job_id'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
    }
    return null;
  }

  Future<AppActionResult> _waitForJob(
    int jobId, {
    required String appName,
    required String actionLabel,
  }) async {
    for (int i = 0; i < _maxJobPolls; i++) {
      if (!mounted) {
        return AppActionResult(ok: true, jobId: jobId);
      }
      try {
        final res = await _client.get('${ApiEndpoints.coreJobs}?id=$jobId');
        Map<String, dynamic>? job;
        if (res.data is List && (res.data as List).isNotEmpty) {
          final first = (res.data as List).first;
          if (first is Map) {
            job = Map<String, dynamic>.from(first);
          }
        } else if (res.data is Map) {
          job = Map<String, dynamic>.from(res.data as Map);
        }

        if (job != null) {
          final stateStr = job['state']?.toString().toUpperCase() ?? '';
          if (stateStr == 'SUCCESS') {
            return AppActionResult(ok: true, jobId: jobId);
          }
          if (stateStr == 'FAILED' || stateStr == 'ABORTED') {
            final err = _extractJobError(job, stateStr);
            return AppActionResult(ok: false, jobId: jobId, errorMessage: err);
          }

          final progress = job['progress'] as Map?;
          final percent = (progress?['percent'] as num?)?.toDouble();
          final description = progress?['description']?.toString();
          _setAppJob(
            appName,
            AppJobProgress(
              action: actionLabel,
              percent: percent,
              description: description,
            ),
          );
        }
      } catch (_) {
        // Ignore transient polling errors while job is executing
      }

      if (i < _maxJobPolls - 1 && _jobPollInterval > Duration.zero) {
        await Future<void>.delayed(_jobPollInterval);
      }
    }

    return AppActionResult(ok: true, jobId: jobId);
  }

  String _extractJobError(Map<String, dynamic> job, String stateStr) {
    final err = job['error']?.toString().trim();
    if (err != null && err.isNotEmpty) return err;
    final excInfo = job['exc_info'];
    if (excInfo is Map && excInfo['repr'] != null) {
      return excInfo['repr'].toString();
    }
    return 'TrueNAS job $stateStr';
  }

  String _extractDioError(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String? detail;
    if (data is Map) {
      detail = (data['message'] ?? data['reason'] ?? data['detail'] ?? data['error'])?.toString();
    } else if (data is String && data.trim().isNotEmpty) {
      detail = data.trim();
    }
    if (detail != null && detail.isNotEmpty) {
      return status != null ? 'HTTP $status: $detail' : detail;
    }
    if (status != null) {
      return 'HTTP $status${error.message != null ? ' (${error.message})' : ''}';
    }
    return error.message ?? error.type.name;
  }
}
