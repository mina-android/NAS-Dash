class ZfsPool {
  final int id;
  final String name;
  final String status;
  final bool healthy;
  final int size; // Raw aggregate size
  final int allocated;
  final int free;
  final String raidType; // RAIDZ1, RAIDZ2, RAIDZ3, MIRROR, STRIPE
  final int diskCount;
  final List<String> diskNames;
  final int usableSize;
  final int usableAllocated;
  final int usableFree;
  final String? scanFunction;
  final double? scanPercentage;

  ZfsPool({
    required this.id,
    required this.name,
    required this.status,
    required this.healthy,
    required this.size,
    required this.allocated,
    required this.free,
    this.raidType = 'STRIPE',
    this.diskCount = 1,
    this.diskNames = const [],
    int? usableSize,
    int? usableAllocated,
    int? usableFree,
    this.scanFunction,
    this.scanPercentage,
  })  : usableSize = usableSize ?? size,
        usableAllocated = usableAllocated ?? allocated,
        usableFree = usableFree ?? free;

  factory ZfsPool.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? rootDataset}) {
    final scan = json['scan'] as Map<String, dynamic>?;
    final rawSize = (json['size'] as num?)?.toInt() ?? 0;
    final rawAllocated = (json['allocated'] as num?)?.toInt() ?? 0;
    final rawFree = (json['free'] as num?)?.toInt() ?? 0;

    // Parse topology
    String detectedRaid = 'STRIPE';
    final List<String> disks = [];
    final topology = json['topology'] as Map<String, dynamic>?;
    final dataVdevs = (topology?['data'] as List?) ?? [];

    if (dataVdevs.isNotEmpty) {
      final firstVdev = dataVdevs.first as Map<String, dynamic>;
      final type = (firstVdev['type'] as String? ?? 'DISK').toUpperCase();

      if (type.contains('RAIDZ3')) {
        detectedRaid = 'RAIDZ3';
      } else if (type.contains('RAIDZ2')) {
        detectedRaid = 'RAIDZ2';
      } else if (type.contains('RAIDZ') || type.contains('RAIDZ1')) {
        detectedRaid = 'RAIDZ1';
      } else if (type.contains('MIRROR')) {
        detectedRaid = 'MIRROR';
      } else if (type.contains('STRIPE') || type == 'DISK') {
        detectedRaid = 'STRIPE';
      } else {
        detectedRaid = type;
      }

      for (final vdev in dataVdevs) {
        final vMap = vdev as Map<String, dynamic>;
        final vChildren = (vMap['children'] as List?) ?? [];
        if (vChildren.isNotEmpty) {
          for (final c in vChildren) {
            final cMap = c as Map<String, dynamic>;
            final dName = cMap['disk'] as String? ?? cMap['device'] as String? ?? cMap['name'] as String?;
            if (dName != null && !disks.contains(dName)) disks.add(dName);
          }
        } else {
          final dName = vMap['disk'] as String? ?? vMap['device'] as String? ?? vMap['name'] as String?;
          if (dName != null && !disks.contains(dName)) disks.add(dName);
        }
      }
    }

    final int diskCount = disks.isNotEmpty ? disks.length : 1;

    // Calculate Usable Storage from Root Dataset if available
    int usableAllocated = rawAllocated;
    int usableFree = rawFree;
    int usableSize = rawSize;

    if (rootDataset != null) {
      final usedObj = rootDataset['used'];
      final availObj = rootDataset['available'];
      final u = usedObj is Map ? (usedObj['parsed'] as num?)?.toInt() : (usedObj as num?)?.toInt();
      final a = availObj is Map ? (availObj['parsed'] as num?)?.toInt() : (availObj as num?)?.toInt();
      if (u != null && a != null) {
        usableAllocated = u;
        usableFree = a;
        usableSize = usableAllocated + usableFree;
      }
    } else {
      // Redundancy estimation fallback
      if (detectedRaid == 'RAIDZ1' && diskCount >= 3) {
        usableSize = (rawSize * (diskCount - 1) ~/ diskCount);
      } else if (detectedRaid == 'RAIDZ2' && diskCount >= 4) {
        usableSize = (rawSize * (diskCount - 2) ~/ diskCount);
      } else if (detectedRaid == 'RAIDZ3' && diskCount >= 5) {
        usableSize = (rawSize * (diskCount - 3) ~/ diskCount);
      } else if (detectedRaid == 'MIRROR' && diskCount >= 2) {
        usableSize = rawSize ~/ diskCount;
      }
      usableAllocated = rawAllocated.clamp(0, usableSize);
      usableFree = (usableSize - usableAllocated).clamp(0, usableSize);
    }

    return ZfsPool(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'ONLINE',
      healthy: json['healthy'] as bool? ?? true,
      size: rawSize,
      allocated: rawAllocated,
      free: rawFree,
      raidType: detectedRaid,
      diskCount: diskCount,
      diskNames: disks,
      usableSize: usableSize,
      usableAllocated: usableAllocated,
      usableFree: usableFree,
      scanFunction: scan?['function'] as String?,
      scanPercentage: (scan?['percentage'] as num?)?.toDouble(),
    );
  }
}

class PhysicalDisk {
  final String name;
  final String model;
  final int size;
  final String type; // SSD or HDD
  final double? temperature;

  PhysicalDisk({
    required this.name,
    required this.model,
    required this.size,
    required this.type,
    this.temperature,
  });

  factory PhysicalDisk.fromJson(Map<String, dynamic> json, {double? temp}) {
    return PhysicalDisk(
      name: json['name'] as String? ?? '',
      model: json['model'] as String? ?? 'Disk',
      size: (json['size'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'HDD',
      temperature: temp,
    );
  }
}

class ZfsDataset {
  final String id;
  final String name;
  final String pool;
  final String mountpoint;
  final String type;
  final int used;
  final int available;
  final String compression;
  final String compressRatio;
  final bool encrypted;

  ZfsDataset({
    required this.id,
    required this.name,
    required this.pool,
    required this.mountpoint,
    required this.type,
    required this.used,
    required this.available,
    required this.compression,
    required this.compressRatio,
    required this.encrypted,
  });

  factory ZfsDataset.fromJson(Map<String, dynamic> json) {
    final usedObj = json['used'];
    final availObj = json['available'];
    final compObj = json['compression'];
    final ratioObj = json['compressratio'];

    return ZfsDataset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pool: json['pool'] as String? ?? '',
      mountpoint: json['mountpoint'] as String? ?? '',
      type: json['type'] as String? ?? 'FILESYSTEM',
      used: usedObj is Map ? (usedObj['parsed'] as num?)?.toInt() ?? 0 : (usedObj as num?)?.toInt() ?? 0,
      available: availObj is Map ? (availObj['parsed'] as num?)?.toInt() ?? 0 : (availObj as num?)?.toInt() ?? 0,
      compression: compObj is Map ? compObj['value'] as String? ?? 'LZ4' : compObj?.toString() ?? 'LZ4',
      compressRatio: ratioObj is Map ? ratioObj['value'] as String? ?? '1.00x' : ratioObj?.toString() ?? '1.00x',
      encrypted: json['encrypted'] as bool? ?? false,
    );
  }
}

class SnapshotTask {
  final int id;
  final String dataset;
  final bool recursive;
  final String state;
  final String? lastSnapshot;

  SnapshotTask({
    required this.id,
    required this.dataset,
    required this.recursive,
    required this.state,
    this.lastSnapshot,
  });

  factory SnapshotTask.fromJson(Map<String, dynamic> json) {
    final st = json['state'] as Map<String, dynamic>?;
    return SnapshotTask(
      id: (json['id'] as num?)?.toInt() ?? 0,
      dataset: json['dataset'] as String? ?? '',
      recursive: json['recursive'] as bool? ?? true,
      state: st?['state'] as String? ?? 'FINISHED',
      lastSnapshot: st?['last_snapshot'] as String?,
    );
  }
}
