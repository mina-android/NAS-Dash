import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../system/providers/system_provider.dart';

class PowerLogsSheet extends StatefulWidget {
  final SystemNotifier systemNotifier;

  const PowerLogsSheet({super.key, required this.systemNotifier});

  @override
  State<PowerLogsSheet> createState() => _PowerLogsSheetState();
}

class _PowerLogsSheetState extends State<PowerLogsSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _powerJobs = [];

  @override
  void initState() {
    super.initState();
    _loadPowerHistory();
  }

  Future<void> _loadPowerHistory() async {
    setState(() => _loading = true);
    final jobs = await widget.systemNotifier.fetchPowerLogs();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _powerJobs = jobs;
    });
  }

  String _formatJobDate(Map<String, dynamic> job) {
    final raw = job['time_started'] ?? job['time_finished'];
    if (raw == null) return 'Date unavailable';

    DateTime? parsed;
    if (raw is Map && raw['\$date'] != null) {
      final val = raw['\$date'];
      if (val is num) {
        final ms = val > 100000000000 ? val.toInt() : (val * 1000).toInt();
        parsed = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
      } else if (val is String) {
        final numVal = int.tryParse(val);
        if (numVal != null) {
          final ms = numVal > 100000000000 ? numVal : numVal * 1000;
          parsed = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
        } else {
          parsed = DateTime.tryParse(val)?.toLocal();
        }
      }
    } else if (raw is num) {
      final ms = raw > 100000000000 ? raw.toInt() : (raw * 1000).toInt();
      parsed = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    } else if (raw is String && raw.isNotEmpty) {
      final numVal = int.tryParse(raw);
      if (numVal != null) {
        final ms = numVal > 100000000000 ? numVal : numVal * 1000;
        parsed = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
      } else {
        parsed = DateTime.tryParse(raw)?.toLocal();
      }
    }

    if (parsed != null) {
      return DateFormat('MMM d, yyyy • h:mm a').format(parsed);
    }
    return raw.toString();
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
                  Icon(Icons.history_toggle_off_rounded, color: colorScheme.onSurfaceVariant, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Host Power & Reboot History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            'Recorded TrueNAS SCALE host restarts, shutdown tasks, and boot events',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 6),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : _powerJobs.isEmpty
                    ? Center(
                        child: Text(
                          'No power command / reboot jobs recorded in core tasks.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _powerJobs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final job = _powerJobs[index];
                          final method = job['method'] as String? ?? 'system.reboot';
                          final state = job['state'] as String? ?? 'SUCCESS';
                          final description = job['description'] as String?;
                          final formattedDate = _formatJobDate(job);
                          final lowerMethod = method.toLowerCase();
                          final isShutdown = lowerMethod.contains('shutdown');
                          final isBoot = lowerMethod.contains('boot');

                          final title = isShutdown
                              ? 'System Shutdown'
                              : isBoot
                                  ? 'Host Boot / Power-On'
                                  : 'System Reboot';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isShutdown
                                        ? Icons.power_settings_new_rounded
                                        : isBoot
                                            ? Icons.bolt_rounded
                                            : Icons.restart_alt_rounded,
                                    size: 18,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (state == 'SUCCESS' || state == 'ONLINE'
                                                      ? AppColors.healthy
                                                      : AppColors.warning)
                                                  .withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              state,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: state == 'SUCCESS' || state == 'ONLINE'
                                                    ? AppColors.healthy
                                                    : AppColors.warning,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today_rounded,
                                            size: 12,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            formattedDate,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        description != null && description.isNotEmpty
                                            ? description
                                            : 'Method: $method',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
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
