import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/models/server_profile.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/providers/telemetry_provider.dart';
import '../providers/landscape_mode_provider.dart';
import '../theme/app_colors.dart';

ButtonStyle frostedAppBarActionStyle(
  BuildContext context, {
  bool isActive = false,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return IconButton.styleFrom(
    backgroundColor: isActive
        ? colorScheme.primaryContainer.withValues(alpha: 0.85)
        : colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.45 : 0.65),
    foregroundColor: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    minimumSize: const Size(36, 36),
    fixedSize: const Size(36, 36),
    padding: EdgeInsets.zero,
  );
}

class FrostedAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final bool showLandscapeToggle;

  const FrostedAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.showLandscapeToggle = true,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  IconData _batteryIcon(int level, bool isCharging) {
    if (isCharging) return Icons.battery_charging_full_rounded;
    if (level >= 90) return Icons.battery_full_rounded;
    if (level >= 75) return Icons.battery_6_bar_rounded;
    if (level >= 60) return Icons.battery_5_bar_rounded;
    if (level >= 45) return Icons.battery_4_bar_rounded;
    if (level >= 30) return Icons.battery_3_bar_rounded;
    if (level >= 15) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isLandscapeLocked = ref.watch(landscapeModeProvider);
    final isLandscapeViewport =
        isLandscapeLocked || MediaQuery.of(context).orientation == Orientation.landscape;

    final deviceStatus = ref.watch(deviceTelemetryProvider);
    final activeServer = ref.watch(activeServerProvider);

    final trailingActions = <Widget>[
      if (actions != null) ...actions!,
      if (showLandscapeToggle)
        IconButton(
          style: frostedAppBarActionStyle(context, isActive: isLandscapeLocked),
          tooltip: isLandscapeLocked
              ? 'Unlock Landscape Dashboard Mode'
              : 'Lock Landscape Dashboard Mode',
          icon: Icon(
            isLandscapeLocked
                ? Icons.screen_lock_landscape_rounded
                : Icons.screen_rotation_rounded,
            size: 19,
          ),
          onPressed: () {
            HapticFeedback.mediumImpact();
            ref.read(landscapeModeProvider.notifier).toggleLandscapeLock();
            ref.read(deviceTelemetryProvider.notifier).refresh();
          },
        ),
    ];

    final spacedTrailing = <Widget>[];
    for (int i = 0; i < trailingActions.length; i++) {
      if (i > 0) spacedTrailing.add(const SizedBox(width: 6));
      spacedTrailing.add(trailingActions[i]);
    }

    final combinedActions = <Widget>[
      if (isLandscapeViewport)
        _LandscapeStatusCluster(
          deviceStatus: deviceStatus,
          activeServer: activeServer,
          batteryIcon: _batteryIcon(deviceStatus.batteryLevel, deviceStatus.isCharging),
          onToggleRoute: (activeServer != null && activeServer.secondaryHost?.isNotEmpty == true)
              ? () {
                  HapticFeedback.lightImpact();
                  final next = activeServer.activeRoute == ActiveRoute.lan
                      ? ActiveRoute.vpn
                      : ActiveRoute.lan;
                  ref.read(authStateProvider.notifier).toggleRoute(activeServer.id, next);
                  ref.read(telemetryProvider.notifier).fetchTelemetry();
                }
              : null,
        ),
      if (isLandscapeViewport && spacedTrailing.isNotEmpty) const SizedBox(width: 4),
      ...spacedTrailing,
      SizedBox(width: isLandscapeViewport ? 12 : 8),
    ];

    return AppBar(
      title: title,
      leading: leading,
      actions: combinedActions,
      bottom: bottom,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerLow.withValues(alpha: 0.72)
                  : colorScheme.surfaceContainerLowest.withValues(alpha: 0.82),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandscapeStatusCluster extends StatelessWidget {
  final DeviceTelemetryStatus deviceStatus;
  final ServerProfile? activeServer;
  final IconData batteryIcon;
  final VoidCallback? onToggleRoute;

  const _LandscapeStatusCluster({
    required this.deviceStatus,
    required this.activeServer,
    required this.batteryIcon,
    this.onToggleRoute,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLan = activeServer?.activeRoute != ActiveRoute.vpn;
    final routeColor = isLan ? AppColors.healthy : colorScheme.primary;
    final batteryColor = deviceStatus.batteryLevel <= 15 && !deviceStatus.isCharging
        ? AppColors.critical
        : (deviceStatus.isCharging ? AppColors.healthy : colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Connection Pill (LAN / VPN)
          if (activeServer != null) ...[
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onToggleRoute,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: routeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: routeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLan ? Icons.wifi_rounded : Icons.vpn_lock_rounded,
                      size: 13,
                      color: routeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isLan ? 'LAN' : 'VPN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: routeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // 2. Phone Battery Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(batteryIcon, size: 14, color: batteryColor),
                const SizedBox(width: 3),
                Text(
                  '${deviceStatus.batteryLevel}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // 3. Desk Clock Time Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_rounded, size: 13, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  deviceStatus.formattedTime,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
