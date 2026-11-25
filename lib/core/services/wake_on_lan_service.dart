import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class WolSendResult {
  final bool ok;
  final String? errorMessage;
  final List<String> targets;

  const WolSendResult({
    required this.ok,
    this.errorMessage,
    this.targets = const [],
  });
}

/// Sends Wake-on-LAN (WoL) UDP magic packets to wake a powered-off TrueNAS host.
class WakeOnLanService {
  const WakeOnLanService();

  static final RegExp _macHexRegex = RegExp(r'^[0-9A-Fa-f]{12}$');

  /// Normalizes a MAC address (colon or hyphen separated) into uppercase `XX:XX:XX:XX:XX:XX`.
  /// Returns `null` if the input is not a valid 48-bit MAC address.
  static String? normalizeMac(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[:\-\.\s]'), '');
    if (!_macHexRegex.hasMatch(cleaned)) return null;
    final upper = cleaned.toUpperCase();
    final buffer = StringBuffer();
    for (var i = 0; i < 12; i += 2) {
      if (i > 0) buffer.write(':');
      buffer.write(upper.substring(i, i + 2));
    }
    return buffer.toString();
  }

  /// Builds a standard 102-byte WoL magic packet (`6 x 0xFF` + `16 x 6-byte MAC`).
  static Uint8List buildMagicPacket(String macAddress) {
    final normalized = normalizeMac(macAddress);
    if (normalized == null) {
      throw ArgumentError.value(macAddress, 'macAddress', 'Invalid MAC address');
    }

    final macBytes = normalized
        .split(':')
        .map((hex) => int.parse(hex, radix: 16))
        .toList(growable: false);

    final packet = Uint8List(102);
    for (var i = 0; i < 6; i++) {
      packet[i] = 0xFF;
    }
    for (var rep = 0; rep < 16; rep++) {
      final offset = 6 + (rep * 6);
      for (var b = 0; b < 6; b++) {
        packet[offset + b] = macBytes[b];
      }
    }
    return packet;
  }

  /// Derives a `/24` directed broadcast IPv4 address from a host or URL (e.g. `https://192.168.1.11` -> `192.168.1.255`).
  static String? deriveSubnetBroadcast(String? hostUrl) {
    if (hostUrl == null || hostUrl.trim().isEmpty) return null;
    var raw = hostUrl.trim();
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }
    final uri = Uri.tryParse(raw);
    final host = uri?.host;
    if (host == null || host.isEmpty) return null;

    final parts = host.split('.');
    if (parts.length != 4) return null;
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((o) => o == null || o < 0 || o > 255)) return null;

    return '${octets[0]}.${octets[1]}.${octets[2]}.255';
  }

  /// Broadcasts the WoL magic packet 3 times with short staggered delays.
  Future<WolSendResult> sendMagicPacket({
    required String macAddress,
    String? broadcastAddress,
    String? lanHost,
    int port = 9,
  }) async {
    final normalizedMac = normalizeMac(macAddress);
    if (normalizedMac == null) {
      return const WolSendResult(
        ok: false,
        errorMessage: 'Invalid MAC address format. Expected XX:XX:XX:XX:XX:XX.',
      );
    }

    final effectivePort = (port >= 1 && port <= 65535) ? port : 9;
    final packet = buildMagicPacket(normalizedMac);

    final targetStrings = <String>{};
    final explicit = broadcastAddress?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      targetStrings.add(explicit);
    } else {
      final derived = deriveSubnetBroadcast(lanHost);
      if (derived != null) {
        targetStrings.add(derived);
      }
    }
    targetStrings.add('255.255.255.255');

    final resolvedTargets = <InternetAddress>[];
    for (final t in targetStrings) {
      final parsed = InternetAddress.tryParse(t);
      if (parsed != null) {
        resolvedTargets.add(parsed);
      } else {
        try {
          final lookedUp = await InternetAddress.lookup(t);
          if (lookedUp.isNotEmpty) {
            resolvedTargets.add(lookedUp.first);
          }
        } catch (_) {}
      }
    }

    if (resolvedTargets.isEmpty) {
      return const WolSendResult(
        ok: false,
        errorMessage: 'Could not resolve any broadcast address.',
      );
    }

    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      for (var burst = 0; burst < 3; burst++) {
        for (final target in resolvedTargets) {
          socket.send(packet, target, effectivePort);
        }
        if (burst < 2) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
      }

      return WolSendResult(
        ok: true,
        targets: resolvedTargets.map((e) => e.address).toList(),
      );
    } catch (e) {
      return WolSendResult(
        ok: false,
        errorMessage: 'Failed to send WoL packet: $e',
      );
    } finally {
      socket?.close();
    }
  }
}
