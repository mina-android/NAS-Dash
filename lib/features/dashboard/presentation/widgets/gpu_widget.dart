import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../models/telemetry_models.dart';

class GpuWidget extends StatelessWidget {
  final GpuData? gpuData;
  final bool isCompact;

  const GpuWidget({super.key, this.gpuData, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    if (gpuData == null) {
      return const SizedBox.shrink();
    }

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
                  const Icon(Icons.videogame_asset_rounded, color: AppColors.healthy, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Dedicated GPU',
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
                  color: AppColors.healthy.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gpuData!.availableToHost ? 'Active' : 'Allocated',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.healthy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            gpuData!.description,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Vendor: ${gpuData!.vendor} • Slot: ${gpuData!.pciSlot}',
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
