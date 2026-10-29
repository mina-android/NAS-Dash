import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../models/telemetry_models.dart';

class SystemSummaryWidget extends StatelessWidget {
  final SystemInfoData systemInfo;
  final String activeRouteLabel;
  final bool isCompact;

  const SystemSummaryWidget({
    super.key,
    required this.systemInfo,
    required this.activeRouteLabel,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.dns_rounded, color: colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        systemInfo.hostname.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'TrueNAS SCALE ${systemInfo.version}',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: activeRouteLabel.contains('LAN')
                      ? AppColors.healthy.withValues(alpha: 0.15)
                      : colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: activeRouteLabel.contains('LAN')
                        ? AppColors.healthy.withValues(alpha: 0.3)
                        : colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      activeRouteLabel.contains('LAN') ? Icons.wifi : Icons.vpn_lock,
                      size: 13,
                      color: activeRouteLabel.contains('LAN') ? AppColors.healthy : colorScheme.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      activeRouteLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: activeRouteLabel.contains('LAN') ? AppColors.healthy : colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isCompact) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoPill(
                    label: 'Hardware',
                    value: systemInfo.systemProduct ?? systemInfo.model.split('@')[0].trim(),
                    icon: Icons.computer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoPill(
                    label: 'Uptime',
                    value: systemInfo.uptime.split('.')[0],
                    icon: Icons.timer_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoPill(
                    label: 'Cores / Threads',
                    value: '${systemInfo.physicalCores}C / ${systemInfo.cores}T',
                    icon: Icons.memory,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoPill(
                    label: 'Load Average',
                    value: systemInfo.loadavg.map((e) => e.toStringAsFixed(2)).join(', '),
                    icon: Icons.speed,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoPill({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
