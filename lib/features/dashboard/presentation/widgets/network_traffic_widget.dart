import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../models/telemetry_models.dart';

class NetworkTrafficWidget extends StatelessWidget {
  final List<NetworkInterfaceTelemetry> interfaces;
  final bool isCompact;

  const NetworkTrafficWidget({
    super.key,
    this.interfaces = const [],
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
                  Icon(Icons.swap_vert_rounded, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Network Interfaces',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.healthy.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${interfaces.length} Active',
                  style: const TextStyle(fontSize: 11, color: AppColors.healthy, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (interfaces.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('No active interfaces detected', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              ),
            )
          else
            ...interfaces.map((iface) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              iface.name.toUpperCase(),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: iface.linkStatus.contains('UP')
                                    ? AppColors.healthy.withValues(alpha: 0.15)
                                    : AppColors.critical.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                iface.linkStatus,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: iface.linkStatus.contains('UP') ? AppColors.healthy : AppColors.critical,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (iface.ipAddress.isNotEmpty)
                          Text(
                            iface.ipAddress,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.healthy),
                              const SizedBox(width: 4),
                              Text('In: ', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                              Text(
                                iface.rxFormatted,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.arrow_upward_rounded, size: 14, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              Text('Out: ', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                              Text(
                                iface.txFormatted,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
