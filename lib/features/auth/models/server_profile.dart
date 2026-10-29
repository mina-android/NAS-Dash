import 'dart:convert';

enum AuthType {
  apiKey,
  credentials,
}

enum ActiveRoute {
  lan,
  vpn,
}

class ServerProfile {
  final String id;
  final String name;
  final String primaryHost; // LAN host, e.g. 192.168.1.11 or https://192.168.1.11
  final String? secondaryHost; // VPN host, e.g. 100.102.141.91
  final AuthType authType;
  final String? username;
  final String? apiKey;
  final String? password;
  final String? smbUsername;
  final String? smbPassword;
  final String? smbDomain;
  final bool allowSelfSigned;
  final ActiveRoute activeRoute;

  ServerProfile({
    required this.id,
    required this.name,
    required this.primaryHost,
    this.secondaryHost,
    required this.authType,
    this.username,
    this.apiKey,
    this.password,
    this.smbUsername,
    this.smbPassword,
    this.smbDomain,
    this.allowSelfSigned = true,
    this.activeRoute = ActiveRoute.lan,
  });

  String get currentHost => activeRoute == ActiveRoute.lan
      ? primaryHost
      : (secondaryHost?.isNotEmpty == true ? secondaryHost! : primaryHost);

  String get normalizedHttpUrl {
    var host = currentHost.trim();
    if (!host.startsWith('http://') && !host.startsWith('https://')) {
      // Default to HTTPS for security and TrueNAS API key preservation
      host = 'https://$host';
    }
    return host.endsWith('/') ? host.substring(0, host.length - 1) : host;
  }

  String get normalizedWsUrl {
    var url = normalizedHttpUrl;
    if (url.startsWith('https://')) {
      url = 'wss://${url.substring(8)}';
    } else if (url.startsWith('http://')) {
      url = 'ws://${url.substring(7)}';
    }
    return '$url/api/current';
  }

  String get smbHost {
    final uri = Uri.tryParse(normalizedHttpUrl);
    return uri?.host ?? currentHost.replaceAll('http://', '').replaceAll('https://', '').split('/')[0];
  }

  ServerProfile copyWith({
    String? id,
    String? name,
    String? primaryHost,
    String? secondaryHost,
    AuthType? authType,
    String? username,
    String? apiKey,
    String? password,
    String? smbUsername,
    String? smbPassword,
    String? smbDomain,
    bool? allowSelfSigned,
    ActiveRoute? activeRoute,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryHost: primaryHost ?? this.primaryHost,
      secondaryHost: secondaryHost ?? this.secondaryHost,
      authType: authType ?? this.authType,
      username: username ?? this.username,
      apiKey: apiKey ?? this.apiKey,
      password: password ?? this.password,
      smbUsername: smbUsername ?? this.smbUsername,
      smbPassword: smbPassword ?? this.smbPassword,
      smbDomain: smbDomain ?? this.smbDomain,
      allowSelfSigned: allowSelfSigned ?? this.allowSelfSigned,
      activeRoute: activeRoute ?? this.activeRoute,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'primaryHost': primaryHost,
      'secondaryHost': secondaryHost,
      'authType': authType.index,
      'username': username,
      'apiKey': apiKey,
      'password': password,
      'smbUsername': smbUsername,
      'smbPassword': smbPassword,
      'smbDomain': smbDomain,
      'allowSelfSigned': allowSelfSigned,
      'activeRoute': activeRoute.index,
    };
  }

  factory ServerProfile.fromMap(Map<String, dynamic> map) {
    return ServerProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      primaryHost: map['primaryHost'] ?? '',
      secondaryHost: map['secondaryHost'],
      authType: AuthType.values[map['authType'] ?? 0],
      username: map['username'],
      apiKey: map['apiKey'],
      password: map['password'],
      smbUsername: map['smbUsername'],
      smbPassword: map['smbPassword'],
      smbDomain: map['smbDomain'],
      allowSelfSigned: map['allowSelfSigned'] ?? true,
      activeRoute: ActiveRoute.values[map['activeRoute'] ?? 0],
    );
  }

  String toJson() => json.encode(toMap());
  factory ServerProfile.fromJson(String source) => ServerProfile.fromMap(json.decode(source));
}
