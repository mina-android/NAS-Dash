import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';

class MemoryArcWidget extends StatelessWidget {
  final int ramUsedBytes;
  final int ramTotalBytes;
  final int ramFreeBytes;
  final int ramCachedBuffersBytes;
  final int arcSizeBytes;
  final double arcHitRatio;
  final int swapTotalBytes;
  final int swapUsedBytes;
  final bool eccMemory;
  final List<double> ramHistory;
  final bool isCompact;

  const MemoryArcWidget({
    super.key,
    required this.ramUsedBytes,
    required this.ramTotalBytes,
    this.ramFreeBytes = 0,
    this.ramCachedBuffersBytes = 0,
    required this.arcSizeBytes,
    required this.arcHitRatio,
    this.swapTotalBytes = 0,
    this.swapUsedBytes = 0,
    this.eccMemory = false,
    this.ramHistory = const [],
    this.isCompact = false,
  });

  String _formatBytes(num bytes) {
    if (bytes >= 1073741824) {
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

    final effectiveTotal = ramTotalBytes > 0 ? ramTotalBytes : 1;
    final totalUsed = ramUsedBytes;
    final arcRatio = (arcSizeBytes / effectiveTotal).clamp(0.0, 1.0);
    final usedRatio = (totalUsed / effectiveTotal).clamp(0.0, 1.0);
    final appRatio = (usedRatio - arcRatio).clamp(0.0, 1.0);
    final cachedRatio = (ramCachedBuffersBytes / effectiveTotal).clamp(0.0, 1.0);
    final freeRatio = (1.0 - appRatio - arcRatio - cachedRatio).clamp(0.0, 1.0);

    final usedPercent = (usedRatio * 100).toStringAsFixed(1);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.memory_rounded, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'RAM & ZFS ARC Memory',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (eccMemory) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.healthy.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.healthy.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'ECC',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.healthy),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$usedPercent% Used',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorScheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Multi-segment memory usage bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (appRatio * 1000).toInt().clamp(1, 1000),
                    child: Container(color: colorScheme.primary),
                  ),
                  Expanded(
                    flex: (arcRatio * 1000).toInt().clamp(1, 1000),
                    child: Container(color: AppColors.secondary),
                  ),
                  if (cachedRatio > 0.01)
                    Expanded(
                      flex: (cachedRatio * 1000).toInt().clamp(1, 1000),
                      child: Container(color: AppColors.warning),
                    ),
                  Expanded(
                    flex: (freeRatio * 1000).toInt().clamp(1, 1000),
                    child: Container(color: colorScheme.surfaceContainerHighest),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 2x3 Compact Telemetry Grid (using Row/Expanded to avoid ScrollView MediaQuery padding)
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  color: colorScheme.primary,
                  title: 'Apps / OS',
                  value: _formatBytes(ramUsedBytes - arcSizeBytes > 0 ? ramUsedBytes - arcSizeBytes : ramUsedBytes),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  color: AppColors.secondary,
                  title: 'ZFS ARC',
                  value: _formatBytes(arcSizeBytes),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  color: AppColors.healthy,
                  title: 'ARC Hit %',
                  value: '${arcHitRatio.toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  color: colorScheme.outline,
                  title: 'Total RAM',
                  value: _formatBytes(ramTotalBytes),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  color: AppColors.healthy,
                  title: 'Free RAM',
                  value: _formatBytes(ramFreeBytes > 0 ? ramFreeBytes : (ramTotalBytes - ramUsedBytes)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  color: AppColors.warning,
                  title: 'Cached / Swap',
                  value: _formatBytes(ramCachedBuffersBytes > 0 ? ramCachedBuffersBytes : swapUsedBytes),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final Color color;
  final String title;
  final String value;

  const _StatTile({required this.color, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
