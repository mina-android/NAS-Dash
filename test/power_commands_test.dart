import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nasdash/core/constants/api_endpoints.dart';
import 'package:nasdash/core/network/truenas_http_client.dart';
import 'package:nasdash/features/auth/models/server_profile.dart';
import 'package:nasdash/features/system/providers/system_provider.dart';

class _RecordedPost {
  final String path;
  final dynamic data;

  _RecordedPost(this.path, this.data);
}

class _FakeTruenasHttpClient implements TruenasHttpClient {
  final List<_RecordedPost> posts = [];
  Future<Response<dynamic>> Function(String path, dynamic data)? onPost;

  @override
  ServerProfile? get profile => null;

  @override
  Ref<Object?> get ref => throw UnimplementedError();

  @override
  late Dio dio = Dio();

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: <dynamic>[] as T,
    );
  }

  @override
  Future<Response<T>> post<T>(String path, {dynamic data}) async {
    posts.add(_RecordedPost(path, data));
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
  group('SystemNotifier Power Commands', () {
    test('reboot sends default reason when none provided', () async {
      final client = _FakeTruenasHttpClient();
      final notifier = SystemNotifier(client);

      final result = await notifier.reboot();

      expect(result.ok, isTrue);
      expect(result.errorMessage, isNull);
      expect(client.posts.length, equals(1));
      expect(client.posts.first.path, equals(ApiEndpoints.systemReboot));
      expect(client.posts.first.data, equals({'reason': 'Rebooted via NAS Dash'}));
    });

    test('shutdown sends custom reason and trims whitespace', () async {
      final client = _FakeTruenasHttpClient();
      final notifier = SystemNotifier(client);

      final result = await notifier.shutdown(reason: '  UPS maintenance  ');

      expect(result.ok, isTrue);
      expect(client.posts.length, equals(1));
      expect(client.posts.first.path, equals(ApiEndpoints.systemShutdown));
      expect(client.posts.first.data, equals({'reason': 'UPS maintenance'}));
    });

    test('empty reason falls back to default reason', () async {
      final client = _FakeTruenasHttpClient();
      final notifier = SystemNotifier(client);

      final result = await notifier.shutdown(reason: '   ');

      expect(result.ok, isTrue);
      expect(client.posts.first.data, equals({'reason': 'Shut down via NAS Dash'}));
    });

    test('falls back to empty JSON body if legacy 24.10 rejects reason', () async {
      final client = _FakeTruenasHttpClient();
      int callCount = 0;
      client.onPost = (path, data) async {
        callCount++;
        if (callCount == 1) {
          throw DioException(
            requestOptions: RequestOptions(path: path),
            response: Response(
              requestOptions: RequestOptions(path: path),
              statusCode: 422,
              data: {'message': 'Unexpected attribute: reason'},
            ),
            type: DioExceptionType.badResponse,
          );
        }
        return Response(requestOptions: RequestOptions(path: path), statusCode: 200);
      };
      final notifier = SystemNotifier(client);

      final result = await notifier.reboot(reason: 'Firmware update');

      expect(result.ok, isTrue);
      expect(client.posts.length, equals(2));
      expect(client.posts[0].data, equals({'reason': 'Firmware update'}));
      expect(client.posts[1].data, equals(<String, dynamic>{}));
    });

    test('returns formatted HTTP error message on failure', () async {
      final client = _FakeTruenasHttpClient();
      client.onPost = (path, data) async {
        throw DioException(
          requestOptions: RequestOptions(path: path),
          response: Response(
            requestOptions: RequestOptions(path: path),
            statusCode: 403,
            data: {'message': 'Insufficient permissions'},
          ),
          type: DioExceptionType.badResponse,
        );
      };
      final notifier = SystemNotifier(client);

      final result = await notifier.shutdown();

      expect(result.ok, isFalse);
      expect(result.errorMessage, equals('HTTP 403: Insufficient permissions'));
    });
  });
}
