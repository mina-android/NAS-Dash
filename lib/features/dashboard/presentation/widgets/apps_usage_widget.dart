import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../apps/presentation/apps_screen.dart';

class AppsUsageWidget extends StatelessWidget {
  final List<Map<String, dynamic>> apps;
  final bool isCompact;

  const AppsUsageWidget({super.key, required this.apps, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final runningCount = apps.where((a) => (a['state'] as String?)?.toUpperCase() == 'RUNNING').length;
    final upgradeCount = apps.where((a) => a['upgrade_available'] == true).length;

    return GlassCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AppsScreen(showBackButton: true)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.apps_rounded, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Installed Apps Overview',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.healthy.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$runningCount Running',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.healthy),
                    ),
                  ),
                  if (upgradeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$upgradeCount Updates',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: apps.map((app) {
              final name = app['name'] as String? ?? 'app';
              final isRunning = (app['state'] as String?)?.toUpperCase() == 'RUNNING';
              final hasUpgrade = app['upgrade_available'] == true;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasUpgrade ? AppColors.warning.withValues(alpha: 0.5) : colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isRunning ? AppColors.healthy : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    ),
                    if (hasUpgrade) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_upward, size: 12, color: AppColors.warning),
                    ],
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
