import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';

class DiskHealthWidget extends StatelessWidget {
  final Map<String, double> diskTemps;
  final bool isCompact;

  const DiskHealthWidget({super.key, required this.diskTemps, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    if (diskTemps.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Disk Health & Temperatures',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: diskTemps.entries.map((entry) {
              final disk = entry.key;
              final temp = entry.value;
              final isHot = temp >= 45.0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isHot ? AppColors.warning : colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.disc_full,
                      size: 14,
                      color: isHot ? AppColors.warning : colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      disk.toUpperCase(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isHot ? AppColors.warning.withValues(alpha: 0.2) : AppColors.healthy.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${temp.toStringAsFixed(0)}°C',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isHot ? AppColors.warning : AppColors.healthy,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
