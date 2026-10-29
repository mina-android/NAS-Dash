class SystemInfoData {
  final String hostname;
  final String version;
  final String model;
  final int cores;
  final int physicalCores;
  final int physmem;
  final String uptime;
  final List<double> loadavg;
  final String? systemProduct;
  final String? systemManufacturer;
  final bool eccMemory;

  SystemInfoData({
    required this.hostname,
    required this.version,
    required this.model,
    required this.cores,
    required this.physicalCores,
    required this.physmem,
    required this.uptime,
    required this.loadavg,
    this.systemProduct,
    this.systemManufacturer,
    this.eccMemory = false,
  });

  factory SystemInfoData.fromJson(Map<String, dynamic> json) {
    return SystemInfoData(
      hostname: json['hostname'] as String? ?? 'TrueNAS',
      version: json['version'] as String? ?? '25.10.x',
      model: json['model'] as String? ?? 'Intel Xeon',
      cores: (json['cores'] as num?)?.toInt() ?? 4,
      physicalCores: (json['physical_cores'] as num?)?.toInt() ?? 4,
      physmem: (json['physmem'] as num?)?.toInt() ?? 8589934592,
      uptime: (json['uptime'] as String? ?? '0:00:00').split('.').first.trim(),
      loadavg: (json['loadavg'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [0.1, 0.1, 0.1],
      systemProduct: json['system_product'] as String?,
      systemManufacturer: json['system_manufacturer'] as String?,
      eccMemory: json['ecc_memory'] as bool? ?? false,
    );
  }
}

class GpuData {
  final String description;
  final String vendor;
  final String pciSlot;
  final bool availableToHost;

  GpuData({
    required this.description,
    required this.vendor,
    required this.pciSlot,
    required this.availableToHost,
  });

  factory GpuData.fromJson(Map<String, dynamic> json) {
    final addr = json['addr'] as Map<String, dynamic>?;
    return GpuData(
      description: json['description'] as String? ?? 'GPU',
      vendor: json['vendor'] as String? ?? 'Unknown',
      pciSlot: addr?['pci_slot'] as String? ?? '0000:00:00.0',
      availableToHost: json['available_to_host'] as bool? ?? true,
    );
  }
}

class NetworkInterfaceTelemetry {
  final String id;
  final String name;
  final String ipAddress;
  final String linkStatus;
  final double rxKilobitsPerSec;
  final double txKilobitsPerSec;

  NetworkInterfaceTelemetry({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.linkStatus,
    required this.rxKilobitsPerSec,
    required this.txKilobitsPerSec,
  });

  String get rxFormatted {
    final bytesPerSec = (rxKilobitsPerSec * 1000) / 8;
    if (bytesPerSec >= 1048576) {
      return '${(bytesPerSec / 1048576).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSec >= 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${bytesPerSec.toStringAsFixed(0)} B/s';
    }
  }

  String get txFormatted {
    final bytesPerSec = (txKilobitsPerSec * 1000) / 8;
    if (bytesPerSec >= 1048576) {
      return '${(bytesPerSec / 1048576).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSec >= 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${bytesPerSec.toStringAsFixed(0)} B/s';
    }
  }
}

class TelemetrySnapshot {
  final SystemInfoData systemInfo;
  final GpuData? gpuData;
  final double cpuUsage;
  final double cpuTemp;
  final List<double> perCoreTemps;
  final int ramUsedBytes;
  final int ramTotalBytes;
  final int ramFreeBytes;
  final int ramCachedBuffersBytes;
  final int arcSizeBytes;
  final double arcHitRatio;
  final int swapTotalBytes;
  final int swapUsedBytes;
  final Map<String, double> diskTemps;
  final List<Map<String, dynamic>> pools;
  final List<Map<String, dynamic>> apps;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> shares;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> jobs;
  final Map<String, dynamic>? bootState;
  final List<NetworkInterfaceTelemetry> networkInterfaces;
  final List<double> cpuHistory;
  final List<double> ramHistory;

  TelemetrySnapshot({
    required this.systemInfo,
    this.gpuData,
    required this.cpuUsage,
    required this.cpuTemp,
    required this.perCoreTemps,
    required this.ramUsedBytes,
    required this.ramTotalBytes,
    this.ramFreeBytes = 0,
    this.ramCachedBuffersBytes = 0,
    required this.arcSizeBytes,
    required this.arcHitRatio,
    this.swapTotalBytes = 0,
    this.swapUsedBytes = 0,
    required this.diskTemps,
    required this.pools,
    required this.apps,
    required this.alerts,
    required this.shares,
    this.services = const [],
    this.jobs = const [],
    this.bootState,
    this.networkInterfaces = const [],
    this.cpuHistory = const [],
    this.ramHistory = const [],
  });
}
