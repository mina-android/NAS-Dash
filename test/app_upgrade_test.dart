import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nasdash/core/constants/api_endpoints.dart';
import 'package:nasdash/core/network/truenas_http_client.dart';
import 'package:nasdash/features/apps/models/app_model.dart';
import 'package:nasdash/features/apps/providers/apps_provider.dart';
import 'package:nasdash/features/auth/models/server_profile.dart';

class _RecordedRequest {
  final String method;
  final String path;
  final dynamic data;

  _RecordedRequest(this.method, this.path, this.data);
}

class _FakeTruenasHttpClient implements TruenasHttpClient {
  final List<_RecordedRequest> requests = [];
  Future<Response<dynamic>> Function(String path, Map<String, dynamic>? query)? onGet;
  Future<Response<dynamic>> Function(String path, dynamic data)? onPost;

  @override
  ServerProfile? get profile => null;

  @override
  Ref<Object?> get ref => throw UnimplementedError();

  @override
  late Dio dio = Dio();

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    requests.add(_RecordedRequest('GET', path, queryParameters));
    if (onGet != null) {
      final res = await onGet!(path, queryParameters);
      return Response<T>(
        requestOptions: res.requestOptions,
        statusCode: res.statusCode,
        data: res.data as T?,
      );
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: <dynamic>[] as T,
    );
  }

  @override
  Future<Response<T>> post<T>(String path, {dynamic data}) async {
    requests.add(_RecordedRequest('POST', path, data));
    if (onPost != null) {
      final res = await onPost!(path, data);
      return Response<T>(
        requestOptions: res.requestOptions,
        statusCode: res.statusCode,
        data: res.data as T?,
      );
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> delete<T>(String path, {dynamic data}) =>
      throw UnimplementedError();
}

void main() {
  group('AppsNotifier Upgrade & Lifecycle', () {
    test('upgradeApp dispatches POST /api/v2.0/app/upgrade with app_name and options and polls job to SUCCESS',
        () async {
      final client = _FakeTruenasHttpClient();
      int jobPollCount = 0;

      client.onGet = (path, _) async {
        if (path.startsWith(ApiEndpoints.coreJobs)) {
          jobPollCount++;
          return Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: [
              {
                'id': 42,
                'state': jobPollCount == 1 ? 'RUNNING' : 'SUCCESS',
                'progress': {'percent': jobPollCount == 1 ? 50 : 100},
              }
            ],
          );
        }
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: <dynamic>[],
        );
      };

      client.onPost = (path, data) async {
        if (path == ApiEndpoints.appUpgrade) {
          return Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: 42,
          );
        }
        return Response(requestOptions: RequestOptions(path: path), statusCode: 200);
      };

      final notifier = AppsNotifier(
        client,
        jobPollInterval: Duration.zero,
      );
      await Future<void>.delayed(Duration.zero);

      final result = await notifier.upgradeApp('plex');

      expect(result.ok, isTrue);
      expect(result.jobId, equals(42));
      expect(result.errorMessage, isNull);
      expect(jobPollCount, equals(2));

      final upgradePost = client.requests.firstWhere(
        (r) => r.method == 'POST' && r.path == ApiEndpoints.appUpgrade,
      );
      expect(
        upgradePost.data,
        equals({'app_name': 'plex', 'options': <String, dynamic>{}}),
      );
    });

    test('upgradeApp surfaces TrueNAS middleware job error when job state is FAILED',
        () async {
      final client = _FakeTruenasHttpClient();
      client.onGet = (path, _) async {
        if (path.startsWith(ApiEndpoints.coreJobs)) {
          return Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: [
              {
                'id': 77,
                'state': 'FAILED',
                'error': '[EFAULT] Failed to render compose templates',
              }
            ],
          );
        }
        return Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: <dynamic>[],
        );
      };
      client.onPost = (path, data) async => Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: 77,
          );

      final notifier = AppsNotifier(client, jobPollInterval: Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final result = await notifier.upgradeApp('immich');

      expect(result.ok, isFalse);
      expect(result.jobId, equals(77));
      expect(result.errorMessage, contains('Failed to render compose templates'));
    });

    test('upgradeApp falls back to app_name-only payload on 422 and legacy /id/ route on 404',
        () async {
      final client = _FakeTruenasHttpClient();
      int postCount = 0;

      client.onPost = (path, data) async {
        postCount++;
        if (postCount == 1) {
          throw DioException(
            requestOptions: RequestOptions(path: path),
            response: Response(
              requestOptions: RequestOptions(path: path),
              statusCode: 422,
              data: {'message': 'options not allowed'},
            ),
            type: DioExceptionType.badResponse,
          );
        }
        if (postCount == 2) {
          throw DioException(
            requestOptions: RequestOptions(path: path),
            response: Response(
              requestOptions: RequestOptions(path: path),
              statusCode: 404,
            ),
            type: DioExceptionType.badResponse,
          );
        }
        return Response(requestOptions: RequestOptions(path: path), statusCode: 200);
      };

      final notifier = AppsNotifier(client, jobPollInterval: Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final result = await notifier.upgradeApp('pihole');

      expect(result.ok, isTrue);
      final posts = client.requests.where((r) => r.method == 'POST').toList();
      expect(posts.length, equals(3));
      expect(posts[0].path, equals(ApiEndpoints.appUpgrade));
      expect(posts[0].data, equals({'app_name': 'pihole', 'options': <String, dynamic>{}}));
      expect(posts[1].path, equals(ApiEndpoints.appUpgrade));
      expect(posts[1].data, equals({'app_name': 'pihole'}));
      expect(posts[2].path, equals('${ApiEndpoints.app}/id/pihole/upgrade'));
    });

    test('startApp and stopApp use /api/v2.0/app/start and /stop with fallback support',
        () async {
      final client = _FakeTruenasHttpClient();
      final notifier = AppsNotifier(client, jobPollInterval: Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final startRes = await notifier.startApp('plex');
      final stopRes = await notifier.stopApp('plex');

      expect(startRes.ok, isTrue);
      expect(stopRes.ok, isTrue);

      final posts = client.requests.where((r) => r.method == 'POST').toList();
      expect(posts[0].path, equals(ApiEndpoints.appStart));
      expect(posts[0].data, equals('"plex"'));
      expect(posts[1].path, equals(ApiEndpoints.appStop));
      expect(posts[1].data, equals('"plex"'));
    });

    test('fetchApps enriches target version via /api/v2.0/app/upgrade_summary when missing',
        () async {
      final client = _FakeTruenasHttpClient();
      client.onGet = (path, _) async {
        if (path == ApiEndpoints.app) {
          return Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: [
              {
                'id': 'plex',
                'name': 'plex',
                'state': 'RUNNING',
                'version': '1.0.100',
                'human_version': '1.40.5',
                'upgrade_available': true,
              },
            ],
          );
        }
        return Response(requestOptions: RequestOptions(path: path), statusCode: 200, data: []);
      };

      client.onPost = (path, data) async {
        if (path == ApiEndpoints.appUpgradeSummary) {
          return Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 200,
            data: {
              'latest_version': '1.0.111',
              'latest_human_version': '1.41.0',
              'upgrade_version': '1.0.111',
              'upgrade_human_version': '1.41.0',
            },
          );
        }
        return Response(requestOptions: RequestOptions(path: path), statusCode: 200);
      };

      final notifier = AppsNotifier(client, jobPollInterval: Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final apps = notifier.state.valueOrNull;
      expect(apps, isNotNull);
      expect(apps!.length, equals(1));
      expect(apps.first.upgradeHumanVersion, equals('1.41.0'));
      expect(apps.first.upgradeVersion, equals('1.0.111'));
    });

    test('upgradeAllApps sequentially upgrades apps and reports mixed results', () async {
      final client = _FakeTruenasHttpClient();
      client.onPost = (path, data) async {
        if (data is Map && data['app_name'] == 'broken-app') {
          throw DioException(
            requestOptions: RequestOptions(path: path),
            response: Response(
              requestOptions: RequestOptions(path: path),
              statusCode: 500,
              data: {'message': 'Docker pull failed'},
            ),
            type: DioExceptionType.badResponse,
          );
        }
        return Response(requestOptions: RequestOptions(path: path), statusCode: 200);
      };

      final notifier = AppsNotifier(client, jobPollInterval: Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final batch = await notifier.upgradeAllApps(['plex', 'broken-app']);

      expect(batch.succeeded, equals(1));
      expect(batch.failed, equals(1));
      expect(batch.errors.length, equals(1));
      expect(batch.errors.first, contains('broken-app'));
      expect(batch.errors.first, contains('Docker pull failed'));
    });

    test('TrueNasApp.copyWith preserves fields and overrides target upgrade version', () {
      final app = TrueNasApp(
        id: 'plex',
        name: 'plex',
        state: 'RUNNING',
        version: '1.0.0',
        humanVersion: '1.40.5',
        upgradeAvailable: true,
      );

      final updated = app.copyWith(
        upgradeVersion: '1.0.1',
        upgradeHumanVersion: '1.41.0',
      );

      expect(updated.name, equals('plex'));
      expect(updated.upgradeVersion, equals('1.0.1'));
      expect(updated.upgradeHumanVersion, equals('1.41.0'));
    });
  });
}
