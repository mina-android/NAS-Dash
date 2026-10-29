import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';

class CpuWidget extends StatelessWidget {
  final double cpuUsage;
  final double cpuTemp;
  final List<double> perCoreTemps;
  final List<double> cpuHistory;
  final bool isCompact;

  const CpuWidget({
    super.key,
    required this.cpuUsage,
    required this.cpuTemp,
    required this.perCoreTemps,
    this.cpuHistory = const [],
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final usagePercent = (cpuUsage / 100.0).clamp(0.0, 1.0);
    final usageColor = cpuUsage > 85
        ? AppColors.critical
        : (cpuUsage > 60 ? AppColors.warning : colorScheme.primary);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.speed_rounded, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'CPU Usage & Thermals',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cpuTemp > 75
                      ? AppColors.critical.withValues(alpha: 0.15)
                      : AppColors.healthy.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${cpuTemp.toStringAsFixed(0)}°C',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cpuTemp > 75 ? AppColors.critical : AppColors.healthy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Overall Load', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                        Text(
                          '${cpuUsage.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: usageColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: usagePercent,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(usageColor),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (perCoreTemps.isNotEmpty && !isCompact) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Core Thermals', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                Text('${perCoreTemps.length} Cores Monitored', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: perCoreTemps.asMap().entries.map((e) {
                final temp = e.value;
                final cColor = temp > 75 ? AppColors.critical : (temp > 60 ? AppColors.warning : AppColors.healthy);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'C${e.key}: ${temp.toStringAsFixed(0)}°',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cColor),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
