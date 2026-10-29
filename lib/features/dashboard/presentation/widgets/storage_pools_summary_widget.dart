import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';

class StoragePoolsSummaryWidget extends StatelessWidget {
  final List<Map<String, dynamic>> pools;
  final Map<String, dynamic>? bootState;
  final bool isCompact;

  const StoragePoolsSummaryWidget({
    super.key,
    required this.pools,
    this.bootState,
    this.isCompact = false,
  });

  String _formatBytes(num bytes) {
    if (bytes >= 1099511627776) {
      return '${(bytes / 1099511627776).toStringAsFixed(1)} TiB';
    } else if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GiB';
    } else if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(0)} MiB';
    }
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (pools.isEmpty && bootState == null) return const SizedBox.shrink();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'ZFS Storage Pools & Boot Drive',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...pools.map((p) {
            final name = p['name'] as String? ?? 'pool';
            final status = p['status'] as String? ?? 'ONLINE';
            final healthy = p['healthy'] as bool? ?? true;
            final size = (p['size'] as num?) ?? 1;
            final allocated = (p['allocated'] as num?) ?? 0;

            // Parse RAID & disk count
            final topology = p['topology'] as Map<String, dynamic>?;
            final dataVdevs = (topology?['data'] as List?) ?? [];
            String raidType = 'STRIPE';
            int diskCount = 1;
            if (dataVdevs.isNotEmpty) {
              final first = dataVdevs.first as Map<String, dynamic>;
              final type = (first['type'] as String? ?? 'DISK').toUpperCase();
              if (type.contains('RAIDZ3')) {
                raidType = 'RAIDZ3';
              } else if (type.contains('RAIDZ2')) {
                raidType = 'RAIDZ2';
              } else if (type.contains('RAIDZ') || type.contains('RAIDZ1')) {
                raidType = 'RAIDZ1';
              } else if (type.contains('MIRROR')) {
                raidType = 'MIRROR';
              }
              final children = (first['children'] as List?) ?? [];
              diskCount = children.isNotEmpty ? children.length : dataVdevs.length;
            }

            num usableSize = size;
            if (raidType == 'RAIDZ1' && diskCount >= 3) {
              usableSize = (size * (diskCount - 1) / diskCount);
            } else if (raidType == 'RAIDZ2' && diskCount >= 4) {
              usableSize = (size * (diskCount - 2) / diskCount);
            } else if (raidType == 'RAIDZ3' && diskCount >= 5) {
              usableSize = (size * (diskCount - 3) / diskCount);
            } else if (raidType == 'MIRROR') {
              usableSize = size / diskCount;
            }

            final ratio = usableSize > 0 ? (allocated / usableSize).clamp(0.0, 1.0) : 0.0;
            final pct = (ratio * 100).toStringAsFixed(1);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$raidType • $diskCount ${diskCount == 1 ? "Disk" : "Disks"}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colorScheme.primary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: healthy
                                  ? AppColors.healthy.withValues(alpha: 0.15)
                                  : AppColors.critical.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: healthy ? AppColors.healthy : AppColors.critical,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${_formatBytes(allocated)} / ${_formatBytes(usableSize)} ($pct%)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ratio > 0.85
                            ? AppColors.critical
                            : (ratio > 0.70 ? AppColors.warning : colorScheme.primary),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),

          // Boot Pool Telemetry (Item 13)
          if (bootState != null && !isCompact) ...[
            const SizedBox(height: 6),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.system_update_alt_rounded, color: colorScheme.primary, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Boot Pool (TrueNAS OS)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (bootState?['status'] as String? ?? 'ONLINE').contains('ONLINE')
                        ? AppColors.healthy.withValues(alpha: 0.15)
                        : AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    bootState?['status'] as String? ?? 'ONLINE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: (bootState?['status'] as String? ?? 'ONLINE').contains('ONLINE')
                          ? AppColors.healthy
                          : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filesystem: ${bootState?['name'] ?? "boot-pool"} • Scrub: ${bootState?['scan']?['state'] ?? "FINISHED"}',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
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
