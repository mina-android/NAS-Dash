import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../system/providers/system_provider.dart';

class ActiveJobsSheet extends StatefulWidget {
  final SystemNotifier systemNotifier;

  const ActiveJobsSheet({super.key, required this.systemNotifier});

  @override
  State<ActiveJobsSheet> createState() => _ActiveJobsSheetState();
}

class _ActiveJobsSheetState extends State<ActiveJobsSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _jobs = [];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _loading = true);
    final jobs = await widget.systemNotifier.fetchActiveJobs();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _jobs = jobs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.pending_actions_rounded, color: colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Active Jobs & Tasks',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _loadJobs,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          Text(
            'Live background jobs running or queued in TrueNAS middleware',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 6),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : _jobs.isEmpty
                    ? Center(
                        child: Text(
                          'No background jobs currently running or recently finished.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _jobs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final job = _jobs[index];
                          final id = (job['id'] as num?)?.toInt() ?? 0;
                          final method = job['method'] as String? ?? 'system.job';
                          final state = job['state'] as String? ?? 'SUCCESS';
                          final progress = job['progress'] as Map<String, dynamic>?;
                          final percent = (progress?['percent'] as num?)?.toDouble() ?? (state == 'SUCCESS' ? 100.0 : 0.0);
                          final desc = progress?['description'] as String? ?? job['description'] as String? ?? '';
                          final isRunning = state == 'RUNNING';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isRunning ? colorScheme.primary.withValues(alpha: 0.3) : colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        method,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isRunning
                                                ? colorScheme.primary
                                                : (state == 'SUCCESS' ? AppColors.healthy : AppColors.warning))
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        state,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isRunning
                                              ? colorScheme.primary
                                              : (state == 'SUCCESS' ? AppColors.healthy : AppColors.warning),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (desc.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(desc, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                                ],
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (percent / 100).clamp(0.0, 1.0),
                                    backgroundColor: colorScheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation(isRunning ? colorScheme.primary : AppColors.healthy),
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Progress: ${percent.toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                                    if (isRunning)
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        ),
                                        onPressed: () async {
                                          final ok = await widget.systemNotifier.abortJob(id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(ok ? 'Abort requested' : 'Failed to abort job')),
                                            );
                                            _loadJobs();
                                          }
                                        },
                                        child: const Text('Abort Task', style: TextStyle(color: AppColors.critical, fontSize: 11)),
                                      ),
                                  ],
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
  }
}
