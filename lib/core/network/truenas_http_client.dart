import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/models/server_profile.dart';
import '../../features/auth/providers/auth_provider.dart';

final truenasHttpClientProvider = Provider<TruenasHttpClient>((ref) {
  final activeServer = ref.watch(activeServerProvider);
  return TruenasHttpClient(activeServer, ref);
});

class TruenasHttpClient {
  final ServerProfile? profile;
  final Ref ref;
  late final Dio dio;

  TruenasHttpClient(this.profile, this.ref) {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 7),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Configure TLS verification to allow self-signed certificates on TrueNAS nodes
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        if (profile?.allowSelfSigned == true) {
          client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        }
        return client;
      },
    );

    // Attach auth headers
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (profile != null) {
            if (profile!.authType == AuthType.apiKey && profile!.apiKey?.isNotEmpty == true) {
              options.headers['Authorization'] = 'Bearer ${profile!.apiKey}';
            } else if (profile!.username != null && profile!.password != null) {
              final basic = base64Encode(utf8.encode('${profile!.username}:${profile!.password}'));
              options.headers['Authorization'] = 'Basic $basic';
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // If connection error on primary host and secondary is available, attempt transparent failover
          if (profile != null &&
              profile!.secondaryHost?.isNotEmpty == true &&
              profile!.activeRoute == ActiveRoute.lan &&
              (error.type == DioExceptionType.connectionTimeout ||
                  error.type == DioExceptionType.connectionError)) {
            ref.read(authStateProvider.notifier).toggleRoute(profile!.id, ActiveRoute.vpn);
          }
          return handler.next(error);
        },
      ),
    );
  }

  String get _baseUrl => profile?.normalizedHttpUrl ?? 'https://192.168.1.11';

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) {
    return dio.get<T>('$_baseUrl$path', queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) {
    return dio.post<T>('$_baseUrl$path', data: data);
  }

  Future<Response<T>> put<T>(String path, {dynamic data}) {
    return dio.put<T>('$_baseUrl$path', data: data);
  }

  Future<Response<T>> delete<T>(String path, {dynamic data}) {
    return dio.delete<T>('$_baseUrl$path', data: data);
  }
}
