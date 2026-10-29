import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/models/server_profile.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../services/notification_service.dart';

final truenasWsClientProvider = Provider<TruenasWsClient>((ref) {
  final activeServer = ref.watch(activeServerProvider);
  return TruenasWsClient(activeServer);
});

class TruenasWsClient {
  final ServerProfile? profile;
  WebSocket? _socket;
  Timer? _reconnectTimer;
  bool _isConnecting = false;

  TruenasWsClient(this.profile) {
    if (profile != null) {
      connect();
    }
  }

  void connect() async {
    if (_isConnecting || profile == null) return;
    _isConnecting = true;

    try {
      final wsUrl = profile!.normalizedWsUrl;
      final securityContext = SecurityContext.defaultContext;

      final client = HttpClient(context: securityContext);
      if (profile!.allowSelfSigned) {
        client.badCertificateCallback = (cert, host, port) => true;
      }

      final uri = Uri.parse(wsUrl);
      final socket = await WebSocket.connect(
        uri.toString(),
        customClient: client,
      ).timeout(const Duration(seconds: 8));

      _socket = socket;
      _isConnecting = false;

      // 1. Authenticate with API Key or Credentials
      if (profile!.authType == AuthType.apiKey && profile!.apiKey?.isNotEmpty == true) {
        _sendRpc('auth.login_with_api_key', [profile!.apiKey!], 1);
      } else if (profile!.username != null && profile!.password != null) {
        _sendRpc('auth.login', [profile!.username!, profile!.password!], 1);
      }

      // 2. Subscribe to Alert events
      _sendRpc('core.subscribe', ['alert.list'], 2);

      // 3. Listen to incoming events
      socket.listen(
        (data) => _handleIncomingMessage(data),
        onDone: () => _scheduleReconnect(),
        onError: (_) => _scheduleReconnect(),
      );
    } catch (_) {
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _sendRpc(String method, List<dynamic> params, int id) {
    if (_socket == null || _socket!.readyState != WebSocket.open) return;
    final payload = json.encode({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
      'id': id,
    });
    _socket!.add(payload);
  }

  void _handleIncomingMessage(dynamic raw) async {
    try {
      final data = json.decode(raw.toString());
      if (data is Map<String, dynamic>) {
        final method = data['method'] as String?;
        final params = data['params'];

        if (method == 'subscription.changed' || method == 'core.subscribe') {
          if (params is Map<String, dynamic>) {
            final collection = params['collection'];
            final fields = params['fields'] as Map<String, dynamic>?;
            if ((collection == 'alert.list' || collection == 'alert') && fields != null) {
              final uuid = fields['id']?.toString() ?? fields['uuid']?.toString() ?? '';
              final level = fields['level']?.toString() ?? 'INFO';
              final formatted = fields['formatted']?.toString() ?? 'New TrueNAS Alert';
              final dismissed = fields['dismissed'] == true;

              if (!dismissed && uuid.isNotEmpty) {
                await NotificationService.instance.showAlertNotification(
                  uuid: uuid,
                  title: 'TrueNAS Alert ($level)',
                  body: formatted,
                  level: level,
                );
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  void _scheduleReconnect() {
    _socket = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 10), () {
      connect();
    });
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _socket?.close();
  }
}
