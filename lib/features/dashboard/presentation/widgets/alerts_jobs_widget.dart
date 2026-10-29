import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../providers/telemetry_provider.dart';

class AlertsJobsWidget extends ConsumerWidget {
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> jobs;
  final bool isCompact;

  const AlertsJobsWidget({
    super.key,
    required this.alerts,
    this.jobs = const [],
    this.isCompact = false,
  });

  void _showDismissedAlertsSheet(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> dismissedAlerts) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.archive_outlined, color: colorScheme.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Dismissed Alerts (${dismissedAlerts.length})',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (dismissedAlerts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No dismissed alerts.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: dismissedAlerts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final alert = dismissedAlerts[index];
                      final uuid = alert['uuid']?.toString() ?? alert['id']?.toString() ?? '';
                      final formatted = alert['formatted'] as String? ?? 'TrueNAS Alert';

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                formatted,
                                style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () async {
                                await ref.read(telemetryProvider.notifier).restoreAlert(uuid);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              icon: const Icon(Icons.restore, size: 16),
                              label: const Text('Restore'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final activeAlerts = alerts.where((a) => a['dismissed'] != true).toList();
    final dismissedAlerts = alerts.where((a) => a['dismissed'] == true).toList();
    final activeJobs = jobs.where((j) {
      final state = (j['state'] as String?)?.toUpperCase();
      return state == 'RUNNING' || state == 'WAITING';
    }).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Dismiss All & Archive actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    activeAlerts.isNotEmpty ? Icons.notifications_active_outlined : Icons.check_circle_outline,
                    color: activeAlerts.isNotEmpty ? AppColors.warning : AppColors.healthy,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'System Alerts & Background Jobs',
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
                  if (activeAlerts.length > 1)
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                      onPressed: () {
                        final uuids = activeAlerts
                            .map((a) => a['uuid']?.toString() ?? a['id']?.toString() ?? '')
                            .where((u) => u.isNotEmpty)
                            .toList();
                        ref.read(telemetryProvider.notifier).dismissAllAlerts(uuids);
                      },
                      child: const Text('Dismiss All', style: TextStyle(fontSize: 11)),
                    ),
                  if (dismissedAlerts.isNotEmpty)
                    IconButton(
                      tooltip: 'View Dismissed Alerts',
                      icon: const Icon(Icons.archive_outlined, size: 18),
                      onPressed: () => _showDismissedAlertsSheet(context, ref, dismissedAlerts),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Alerts list
          if (activeAlerts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined, color: AppColors.healthy, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'No active system alerts. All services nominal.',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ...activeAlerts.take(4).map((alert) {
              final uuid = alert['uuid']?.toString() ?? alert['id']?.toString() ?? '';
              final formatted = alert['formatted'] as String? ?? 'Alert';
              final level = (alert['level'] as String?)?.toUpperCase() ?? 'INFO';
              final color = level == 'CRITICAL' || level == 'ERROR'
                  ? AppColors.critical
                  : (level == 'WARNING' ? AppColors.warning : AppColors.info);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formatted,
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss alert',
                      icon: const Icon(Icons.close_rounded, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        ref.read(telemetryProvider.notifier).dismissAlert(uuid);
                      },
                    ),
                  ],
                ),
              );
            }),

          // Active Background Jobs Monitor (Item 13)
          if (activeJobs.isNotEmpty && !isCompact) ...[
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.sync_rounded, color: colorScheme.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Active Jobs (${activeJobs.length})',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...activeJobs.take(3).map((job) {
              final method = job['method'] as String? ?? 'Task';
              final progress = job['progress'] as Map<String, dynamic>?;
              final percent = (progress?['percent'] as num?)?.toDouble() ?? 0.0;
              final description = progress?['description'] as String? ?? method;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          description,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                        ),
                        Text(
                          '${percent.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (percent / 100).clamp(0.0, 1.0),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
