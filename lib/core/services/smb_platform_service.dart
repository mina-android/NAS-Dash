import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final smbPlatformServiceProvider = Provider<SmbPlatformService>((ref) {
  return SmbPlatformService();
});

class SmbItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final int lastModified;
  final bool canRead;
  final bool canWrite;

  SmbItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.lastModified,
    required this.canRead,
    required this.canWrite,
  });

  factory SmbItem.fromMap(Map<dynamic, dynamic> map) {
    return SmbItem(
      name: map['name'] as String? ?? '',
      path: map['path'] as String? ?? '',
      isDirectory: map['isDirectory'] as bool? ?? false,
      size: (map['size'] as num?)?.toInt() ?? 0,
      lastModified: (map['lastModified'] as num?)?.toInt() ?? 0,
      canRead: map['canRead'] as bool? ?? true,
      canWrite: map['canWrite'] as bool? ?? true,
    );
  }
}

class SmbClipboardItem {
  final SmbItem item;
  final String sourceUrl;
  final bool isCut;

  SmbClipboardItem({
    required this.item,
    required this.sourceUrl,
    required this.isCut,
  });
}

class SmbPlatformService {
  static const MethodChannel _channel = MethodChannel('com.ma.nasdash/smb');

  Future<List<SmbItem>> listFiles({
    required String host,
    required String share,
    required String path,
    String? username,
    String? password,
    String? domain,
  }) async {
    final List<dynamic>? result = await _channel.invokeListMethod('listFiles', {
      'host': host,
      'share': share,
      'path': path,
      'username': username,
      'password': password,
      'domain': domain,
    });
    if (result == null) return [];
    return result.map((e) => SmbItem.fromMap(e as Map<dynamic, dynamic>)).toList();
  }

  Future<bool> createFolder({
    required String url,
    String? username,
    String? password,
    String? domain,
  }) async {
    final bool? result = await _channel.invokeMethod<bool>('createFolder', {
      'url': url,
      'username': username,
      'password': password,
      'domain': domain,
    });
    return result ?? false;
  }

  Future<bool> rename({
    required String sourceUrl,
    required String newName,
    String? username,
    String? password,
    String? domain,
  }) async {
    final bool? result = await _channel.invokeMethod<bool>('rename', {
      'sourceUrl': sourceUrl,
      'newName': newName,
      'username': username,
      'password': password,
      'domain': domain,
    });
    return result ?? false;
  }

  Future<bool> delete({
    required String url,
    String? username,
    String? password,
    String? domain,
  }) async {
    final bool? result = await _channel.invokeMethod<bool>('delete', {
      'url': url,
      'username': username,
      'password': password,
      'domain': domain,
    });
    return result ?? false;
  }

  Future<bool> copy({
    required String sourceUrl,
    required String destUrl,
    String? username,
    String? password,
    String? domain,
  }) async {
    final bool? result = await _channel.invokeMethod<bool>('copy', {
      'sourceUrl': sourceUrl,
      'destUrl': destUrl,
      'username': username,
      'password': password,
      'domain': domain,
    });
    return result ?? false;
  }

  Future<bool> move({
    required String sourceUrl,
    required String destUrl,
    String? username,
    String? password,
    String? domain,
  }) async {
    final bool? result = await _channel.invokeMethod<bool>('move', {
      'sourceUrl': sourceUrl,
      'destUrl': destUrl,
      'username': username,
      'password': password,
      'domain': domain,
    });
    return result ?? false;
  }
}
