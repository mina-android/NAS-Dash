import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_profile.dart';

const String _kActiveServerIdKey = 'nas_dash_active_server_id';
const String _kServerProfilesKey = 'nas_dash_server_profiles_v1';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );
});

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<List<ServerProfile>>>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return AuthNotifier(secureStorage, ref);
});

final activeServerIdProvider = StateProvider<String?>((ref) => null);

final activeServerProvider = Provider<ServerProfile?>((ref) {
  final servers = ref.watch(authStateProvider).valueOrNull ?? [];
  if (servers.isEmpty) return null;
  final activeId = ref.watch(activeServerIdProvider);
  if (activeId != null) {
    return servers.firstWhere((s) => s.id == activeId, orElse: () => servers.first);
  }
  return servers.first;
});

class AuthNotifier extends StateNotifier<AsyncValue<List<ServerProfile>>> {
  final FlutterSecureStorage _secureStorage;
  final Ref _ref;

  AuthNotifier(this._secureStorage, this._ref) : super(const AsyncValue.loading()) {
    loadProfiles();
  }

  Future<void> loadProfiles() async {
    try {
      final raw = await _secureStorage
          .read(key: _kServerProfilesKey)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = json.decode(raw);
        final profiles = decoded.map((m) => ServerProfile.fromMap(m as Map<String, dynamic>)).toList();
        state = AsyncValue.data(profiles);

        final prefs = await SharedPreferences.getInstance();
        final activeId = prefs.getString(_kActiveServerIdKey);
        if (activeId != null && profiles.any((p) => p.id == activeId)) {
          _ref.read(activeServerIdProvider.notifier).state = activeId;
        } else if (profiles.isNotEmpty) {
          await prefs.setString(_kActiveServerIdKey, profiles.first.id);
          _ref.read(activeServerIdProvider.notifier).state = profiles.first.id;
        }
      } else {
        // No pre-seeded profile: user must go through Onboarding
        state = const AsyncValue.data([]);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setActiveServer(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveServerIdKey, id);
    _ref.read(activeServerIdProvider.notifier).state = id;
  }

  Future<bool> testConnection(ServerProfile profile) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
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
      final url = '${profile.normalizedHttpUrl}/api/v2.0/system/info';
      final res = await dio.get(url, options: Options(headers: headers));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveProfiles(List<ServerProfile> profiles) async {
    final raw = json.encode(profiles.map((p) => p.toMap()).toList());
    await _secureStorage.write(key: _kServerProfilesKey, value: raw);
  }

  Future<void> saveProfile(ServerProfile profile) async {
    final current = state.valueOrNull ?? [];
    final index = current.indexWhere((p) => p.id == profile.id);
    List<ServerProfile> updated;
    if (index >= 0) {
      updated = List.from(current)..[index] = profile;
    } else {
      updated = [...current, profile];
    }
    state = AsyncValue.data(updated);
    await _saveProfiles(updated);
    await setActiveServer(profile.id);
  }

  Future<void> deleteProfile(String id) async {
    final current = state.valueOrNull ?? [];
    final updated = current.where((p) => p.id != id).toList();
    state = AsyncValue.data(updated);
    await _saveProfiles(updated);
    if (updated.isNotEmpty) {
      await setActiveServer(updated.first.id);
    } else {
      _ref.read(activeServerIdProvider.notifier).state = null;
    }
  }

  Future<void> toggleRoute(String profileId, ActiveRoute newRoute) async {
    final current = state.valueOrNull ?? [];
    final updated = current.map((p) {
      if (p.id == profileId) {
        return p.copyWith(activeRoute: newRoute);
      }
      return p;
    }).toList();
    state = AsyncValue.data(updated);
    await _saveProfiles(updated);
  }
}
