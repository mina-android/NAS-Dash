import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/landscape_mode_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/models/server_profile.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/telemetry_provider.dart';

/// True-black (#000000) OLED Always-On Display overlay shown in Landscape
/// Dashboard mode after 30 seconds of user inactivity.
class LandscapeAodOverlay extends ConsumerStatefulWidget {
  final VoidCallback onWake;

  const LandscapeAodOverlay({
    super.key,
    required this.onWake,
  });

  @override
  ConsumerState<LandscapeAodOverlay> createState() =>
      _LandscapeAodOverlayState();
}

class _LandscapeAodOverlayState extends ConsumerState<LandscapeAodOverlay> {
  static const List<Offset> _burnInShifts = [
    Offset(0, 0),
    Offset(6, -4),
    Offset(-6, -4),
    Offset(-6, 4),
    Offset(6, 4),
  ];

  int _shiftIndex = 0;
  Timer? _shiftTimer;

  @override
  void initState() {
    super.initState();
    _shiftTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      setState(() {
        _shiftIndex = (_shiftIndex + 1) % _burnInShifts.length;
      });
    });
  }

  @override
  void dispose() {
    _shiftTimer?.cancel();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var val = bytes.toDouble();
    var idx = 0;
    while (val >= 1024 && idx < units.length - 1) {
      val /= 1024;
      idx++;
    }
    return '${val.toStringAsFixed(val >= 10 ? 1 : 2)} ${units[idx]}';
  }

  String _formatRate(double kbps) {
    if (kbps < 1000) return '${kbps.toStringAsFixed(0)} Kb/s';
    final mbps = kbps / 1000.0;
    if (mbps < 1000) return '${mbps.toStringAsFixed(1)} Mb/s';
    return '${(mbps / 1000.0).toStringAsFixed(2)} Gb/s';
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryProvider).valueOrNull;
    final deviceStatus = ref.watch(deviceTelemetryProvider);
    final activeServer = ref.watch(activeServerProvider);
    final routeLabel =
        activeServer?.activeRoute == ActiveRoute.vpn ? 'VPN' : 'LAN';
    final shift = _burnInShifts[_shiftIndex];
    final dateStr = DateFormat('EEE, MMM d').format(DateTime.now());

    final ramPct = telemetry != null && telemetry.ramTotalBytes > 0
        ? (telemetry.ramUsedBytes / telemetry.ramTotalBytes * 100)
            .clamp(0.0, 100.0)
        : 0.0;

    final totalRxKbps = telemetry?.networkInterfaces.fold<double>(
          0.0,
          (sum, iface) => sum + iface.rxKilobitsPerSec,
        ) ??
        0.0;
    final totalTxKbps = telemetry?.networkInterfaces.fold<double>(
          0.0,
          (sum, iface) => sum + iface.txKilobitsPerSec,
        ) ??
        0.0;

    final pools = telemetry?.pools ?? const [];
    final onlinePools = pools
        .where((p) => (p['status'] as String? ?? '').toUpperCase() == 'ONLINE')
        .length;
    final activeAlerts = telemetry?.alerts
            .where((a) => a['dismissed'] != true)
            .length ??
        0;

    int totalPoolSize = 0;
    int totalPoolAllocated = 0;
    for (final p in pools) {
      final size = (p['size'] as num?)?.toInt() ?? 0;
      final allocated = (p['allocated'] as num?)?.toInt() ?? 0;
      totalPoolSize += size;
      totalPoolAllocated += allocated;
    }
    final poolUsedPct = totalPoolSize > 0
        ? (totalPoolAllocated / totalPoolSize * 100).clamp(0.0, 100.0)
        : null;

    final cleanUptime =
        (telemetry?.systemInfo.uptime ?? '--').split('.').first.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onWake,
      onPanDown: (_) => widget.onWake(),
      child: Material(
        color: Colors.black,
        child: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            padding: EdgeInsets.fromLTRB(
              28 + shift.dx,
              20 + shift.dy,
              28 - shift.dx,
              18 - shift.dy,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left Pane: Clock, Date, Host, Route, Phone Battery
                      Expanded(
                        flex: 5,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deviceStatus.formattedTime,
                              style: TextStyle(
                                fontSize: 64,
                                height: 1.0,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.5,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.58),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.healthy,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    telemetry?.systemInfo.hostname ??
                                        activeServer?.name ??
                                        'TrueNAS',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.82),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.22),
                                    ),
                                  ),
                                  child: Text(
                                    routeLabel,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(alpha: 0.72),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  deviceStatus.isCharging
                                      ? Icons.battery_charging_full_rounded
                                      : Icons.battery_std_rounded,
                                  size: 16,
                                  color: deviceStatus.isCharging
                                      ? AppColors.healthy.withValues(alpha: 0.85)
                                      : Colors.white.withValues(alpha: 0.55),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${deviceStatus.batteryLevel}%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    color: Colors.white.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Pane: 2x3 OLED Telemetry Grid
                      Expanded(
                        flex: 7,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _AodMetricTile(
                                    icon: Icons.speed_rounded,
                                    label: 'CPU',
                                    primaryValue: telemetry != null
                                        ? '${telemetry.cpuUsage.toStringAsFixed(1)}%'
                                        : '--',
                                    secondaryValue: telemetry != null
                                        ? '${telemetry.cpuTemp.toStringAsFixed(0)}°C'
                                        : '--',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _AodMetricTile(
                                    icon: Icons.memory_rounded,
                                    label: 'RAM & ARC',
                                    primaryValue: telemetry != null
                                        ? '${ramPct.toStringAsFixed(1)}%'
                                        : '--',
                                    secondaryValue: telemetry != null
                                        ? 'ARC ${_formatBytes(telemetry.arcSizeBytes)}'
                                        : '--',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _AodMetricTile(
                                    icon: Icons.storage_rounded,
                                    label: 'POOLS',
                                    primaryValue: pools.isNotEmpty
                                        ? '$onlinePools/${pools.length} OK'
                                        : '--',
                                    secondaryValue: poolUsedPct != null
                                        ? '${poolUsedPct.toStringAsFixed(0)}% used'
                                        : 'No pools',
                                    accentColor: pools.isNotEmpty &&
                                            onlinePools == pools.length
                                        ? AppColors.healthy.withValues(alpha: 0.85)
                                        : AppColors.warning.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _AodMetricTile(
                                    icon: Icons.swap_vert_rounded,
                                    label: 'NETWORK',
                                    primaryValue: '↓ ${_formatRate(totalRxKbps)}',
                                    secondaryValue: '↑ ${_formatRate(totalTxKbps)}',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _AodMetricTile(
                                    icon: Icons.notifications_none_rounded,
                                    label: 'ALERTS',
                                    primaryValue: activeAlerts == 0
                                        ? 'None'
                                        : '$activeAlerts Active',
                                    secondaryValue: activeAlerts == 0
                                        ? 'System nominal'
                                        : 'Tap to inspect',
                                    accentColor: activeAlerts > 0
                                        ? AppColors.warning.withValues(alpha: 0.9)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _AodMetricTile(
                                    icon: Icons.schedule_rounded,
                                    label: 'UPTIME',
                                    primaryValue: cleanUptime,
                                    secondaryValue: 'TrueNAS SCALE',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Tap anywhere to wake',
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 0.4,
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AodMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String primaryValue;
  final String secondaryValue;
  final Color? accentColor;

  const _AodMetricTile({
    required this.icon,
    required this.label,
    required this.primaryValue,
    required this.secondaryValue,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: Colors.white.withValues(alpha: 0.48),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: Colors.white.withValues(alpha: 0.48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            primaryValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: accentColor ?? Colors.white.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            secondaryValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.52),
            ),
          ),
        ],
      ),
    );
  }
}
