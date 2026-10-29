import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../system/providers/system_provider.dart';

class BootPoolSheet extends StatefulWidget {
  final SystemNotifier systemNotifier;

  const BootPoolSheet({super.key, required this.systemNotifier});

  @override
  State<BootPoolSheet> createState() => _BootPoolSheetState();
}

class _BootPoolSheetState extends State<BootPoolSheet> {
  bool _loading = true;
  Map<String, dynamic>? _bootState;

  @override
  void initState() {
    super.initState();
    _loadBootState();
  }

  Future<void> _loadBootState() async {
    setState(() => _loading = true);
    final data = await widget.systemNotifier.fetchBootState();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _bootState = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final status = _bootState?['status'] as String? ?? 'ONLINE';
    final isHealthy = status.toUpperCase() == 'ONLINE';
    final scan = _bootState?['scan'] as Map<String, dynamic>?;
    final scanFunc = scan?['function'] as String? ?? 'SCRUB';
    final scanErrors = scan?['errors']?.toString() ?? '0';

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.70,
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
                  Icon(Icons.shield_outlined, color: isHealthy ? AppColors.healthy : AppColors.critical, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'OS Boot Pool & SSD Health',
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
            'TrueNAS SCALE root boot drive mirror status, wear, and ZFS scrub health',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : _bootState == null
                    ? Center(
                        child: Text(
                          'Unable to query boot pool state.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView(
                        children: [
                          GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (isHealthy ? AppColors.healthy : AppColors.critical).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
                                    color: isHealthy ? AppColors.healthy : AppColors.critical,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Boot Pool: $status',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isHealthy ? 'Boot drives operating optimally without ZFS checksum errors' : 'Attention needed on OS boot drives',
                                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          GlassCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ZFS Boot Scrub Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                                const SizedBox(height: 6),
                                Text('Function: $scanFunc', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                                Text('Checksum Errors: $scanErrors', style: TextStyle(fontSize: 11, color: scanErrors == '0' ? AppColors.healthy : AppColors.critical)),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
