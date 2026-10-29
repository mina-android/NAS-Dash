enum DashboardWidgetType {
  systemSummary,
  cpuUsage,
  cpuTemp,
  gpuStatus,
  memoryArc,
  appsUsage,
  storagePools,
  diskHealthIo,
  networkTraffic,
  alertsJobs,
  sharesServices,
  upsStatus,
}

enum WidgetCardSize {
  compact,
  expanded,
}

class DashboardWidgetConfig {
  final DashboardWidgetType type;
  final bool isVisible;
  final int order;
  final WidgetCardSize size;
  final bool isCollapsed;

  DashboardWidgetConfig({
    required this.type,
    required this.isVisible,
    required this.order,
    this.size = WidgetCardSize.expanded,
    this.isCollapsed = false,
  });

  String get displayName {
    switch (type) {
      case DashboardWidgetType.systemSummary:
        return 'System & Host Summary';
      case DashboardWidgetType.cpuUsage:
        return 'CPU Usage & Cores';
      case DashboardWidgetType.cpuTemp:
        return 'CPU Temperatures';
      case DashboardWidgetType.gpuStatus:
        return 'GPU Hardware & State';
      case DashboardWidgetType.memoryArc:
        return 'RAM & ZFS ARC Memory';
      case DashboardWidgetType.appsUsage:
        return 'Installed Apps Usage';
      case DashboardWidgetType.storagePools:
        return 'Storage Pools Capacity';
      case DashboardWidgetType.diskHealthIo:
        return 'Disk Health & Temps';
      case DashboardWidgetType.networkTraffic:
        return 'Network Interfaces';
      case DashboardWidgetType.alertsJobs:
        return 'Alerts & Active Jobs';
      case DashboardWidgetType.sharesServices:
        return 'SMB Shares & Services';
      case DashboardWidgetType.upsStatus:
        return 'UPS Power Monitor';
    }
  }

  DashboardWidgetConfig copyWith({
    bool? isVisible,
    int? order,
    WidgetCardSize? size,
    bool? isCollapsed,
  }) {
    return DashboardWidgetConfig(
      type: type,
      isVisible: isVisible ?? this.isVisible,
      order: order ?? this.order,
      size: size ?? this.size,
      isCollapsed: isCollapsed ?? this.isCollapsed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'isVisible': isVisible,
      'order': order,
      'size': size.index,
      'isCollapsed': isCollapsed,
    };
  }

  factory DashboardWidgetConfig.fromMap(Map<String, dynamic> map) {
    return DashboardWidgetConfig(
      type: DashboardWidgetType.values[map['type'] ?? 0],
      isVisible: map['isVisible'] ?? true,
      order: map['order'] ?? 0,
      size: WidgetCardSize.values[map['size'] ?? 1],
      isCollapsed: map['isCollapsed'] ?? false,
    );
  }
}
