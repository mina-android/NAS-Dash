import 'package:flutter/material.dart';
import '../../../../core/widgets/glass_card.dart';

class SharesServicesWidget extends StatelessWidget {
  final List<Map<String, dynamic>> shares;
  final List<Map<String, dynamic>> services;
  final bool isCompact;

  const SharesServicesWidget({
    super.key,
    required this.shares,
    this.services = const [],
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
            children: [
              Icon(Icons.folder_shared_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'SMB File Shares',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (shares.isEmpty)
            Text('No configured SMB shares', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: shares.map((s) {
                final name = s['name'] as String? ?? 'share';
                final path = s['path'] as String? ?? '';
                final enabled = s['enabled'] as bool? ?? true;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder,
                        size: 15,
                        color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                          ),
                          if (path.isNotEmpty)
                            Text(
                              path,
                              style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                            ),
                        ],
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
