class TrueNasApp {
  final String id;
  final String name;
  final String state;
  final String version;
  final String humanVersion;
  final bool upgradeAvailable;
  final String? upgradeVersion;
  final String? upgradeHumanVersion;
  final String? icon;
  final String? portalUrl;

  TrueNasApp({
    required this.id,
    required this.name,
    required this.state,
    required this.version,
    required this.humanVersion,
    required this.upgradeAvailable,
    this.upgradeVersion,
    this.upgradeHumanVersion,
    this.icon,
    this.portalUrl,
  });

  factory TrueNasApp.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>?;
    final chartMetadata = json['chart_metadata'] as Map<String, dynamic>?;
    final portals = json['portals'] as Map<String, dynamic>?;
    String? webPortal;
    if (portals != null && portals.isNotEmpty) {
      webPortal = portals.values.first?.toString();
    }

    final availableVersions = json['available_versions_for_upgrade'] as List?;
    final firstAvailable = (availableVersions != null &&
            availableVersions.isNotEmpty &&
            availableVersions.first is Map)
        ? Map<String, dynamic>.from(availableVersions.first as Map)
        : null;

    final upHuman = json['upgrade_human_version'] as String? ??
        json['latest_human_version'] as String? ??
        firstAvailable?['human_version'] as String? ??
        metadata?['latest_version'] as String? ??
        chartMetadata?['latest_chart_version'] as String?;
    final upVer = json['upgrade_version'] as String? ??
        json['latest_version'] as String? ??
        firstAvailable?['version'] as String? ??
        metadata?['upgrade_version'] as String? ??
        chartMetadata?['version'] as String?;

    final rawIcon = (metadata?['icon'] as String?) ??
        (chartMetadata?['icon'] as String?) ??
        (json['icon_url'] as String?) ??
        (json['icon'] as String?);

    return TrueNasApp(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      state: json['state'] as String? ?? 'STOPPED',
      version: json['version'] as String? ?? '',
      humanVersion: json['human_version'] as String? ?? '',
      upgradeAvailable: json['upgrade_available'] as bool? ?? false,
      upgradeVersion: upVer,
      upgradeHumanVersion: upHuman,
      icon: (rawIcon != null && rawIcon.trim().isNotEmpty) ? rawIcon.trim() : null,
      portalUrl: webPortal,
    );
  }

  bool get isRunning => state.toUpperCase() == 'RUNNING';

  TrueNasApp copyWith({
    String? id,
    String? name,
    String? state,
    String? version,
    String? humanVersion,
    bool? upgradeAvailable,
    String? upgradeVersion,
    String? upgradeHumanVersion,
    String? icon,
    String? portalUrl,
  }) {
    return TrueNasApp(
      id: id ?? this.id,
      name: name ?? this.name,
      state: state ?? this.state,
      version: version ?? this.version,
      humanVersion: humanVersion ?? this.humanVersion,
      upgradeAvailable: upgradeAvailable ?? this.upgradeAvailable,
      upgradeVersion: upgradeVersion ?? this.upgradeVersion,
      upgradeHumanVersion: upgradeHumanVersion ?? this.upgradeHumanVersion,
      icon: icon ?? this.icon,
      portalUrl: portalUrl ?? this.portalUrl,
    );
  }
}
