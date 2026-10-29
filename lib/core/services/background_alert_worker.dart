import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';
import '../../features/auth/models/server_profile.dart';
import '../constants/api_endpoints.dart';
import 'notification_service.dart';

const String kAlertCheckPeriodicTask = 'com.ma.nasdash.alertCheckPeriodic';
const String _kServerProfilesKey = 'nas_dash_server_profiles_v1';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await NotificationService.instance.initialize();
      const secureStorage = FlutterSecureStorage();
      final raw = await secureStorage.read(key: _kServerProfilesKey);
      if (raw == null || raw.isEmpty) return true;

      final List<dynamic> decoded = json.decode(raw);
      if (decoded.isEmpty) return true;

      final profile = ServerProfile.fromMap(decoded.first as Map<String, dynamic>);

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Accept': 'application/json'},
        ),
      );

      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          if (profile.allowSelfSigned) {
            client.badCertificateCallback = (cert, host, port) => true;
          }
          return client;
        },
      );

      final headers = <String, String>{};
      if (profile.authType == AuthType.apiKey && profile.apiKey?.isNotEmpty == true) {
        headers['Authorization'] = 'Bearer ${profile.apiKey}';
      } else if (profile.username != null && profile.password != null) {
        final basic = base64Encode(utf8.encode('${profile.username}:${profile.password}'));
        headers['Authorization'] = 'Basic $basic';
      }

      final url = '${profile.normalizedHttpUrl}${ApiEndpoints.alertList}';
      final res = await dio.get(url, options: Options(headers: headers));

      if (res.data is List) {
        for (final item in res.data as List) {
          final map = item as Map<String, dynamic>;
          final dismissed = map['dismissed'] as bool? ?? false;
          if (dismissed) continue;

          final uuid = map['uuid'] as String? ?? map['id']?.toString() ?? '';
          final level = (map['level'] as String?)?.toUpperCase() ?? 'INFO';
          final formatted = map['formatted'] as String? ?? 'TrueNAS Alert';

          await NotificationService.instance.showAlertNotification(
            uuid: uuid,
            title: 'TrueNAS Alert ($level)',
            body: formatted,
            level: level,
          );
        }
      }
      return true;
    } catch (_) {
      return true;
    }
  });
}
