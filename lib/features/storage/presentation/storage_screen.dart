import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/frosted_app_bar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/refresh_action_button.dart';
import '../providers/storage_provider.dart';

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatBytes(num bytes) {
    if (bytes >= 1099511627776) {
      return '${(bytes / 1099511627776).toStringAsFixed(2)} TiB';
    } else if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GiB';
    } else if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(0)} MiB';
    }
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final storageState = ref.watch(storageProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight + kTextTabBarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FrostedAppBar(
        title: const Text('Storage & Datasets'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(text: 'Pools & VDEVs'),
            Tab(text: 'Physical Disks'),
            Tab(text: 'Datasets Tree'),
          ],
        ),
        actions: [
          RefreshActionButton(
            onRefresh: () => ref.read(storageProvider.notifier).fetchStorage(),
          ),
        ],
      ),
      body: storageState.when(
        loading: () => Center(child: CircularProgressIndicator(color: colorScheme.primary)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.critical, size: 40),
                const SizedBox(height: 8),
                Text('Storage Error: $err', style: const TextStyle(color: AppColors.critical), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => ref.read(storageProvider.notifier).fetchStorage(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          return TabBarView(
            controller: _tabController,
            children: [
              // 1. Pools & VDEVs
              ListView.separated(
                padding: EdgeInsets.fromLTRB(16, topPadding, 16, 96),
                itemCount: data.pools.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final pool = data.pools[index];
                  final ratio = pool.usableSize > 0 ? (pool.usableAllocated / pool.usableSize).clamp(0.0, 1.0) : 0.0;
                  final percentage = (ratio * 100).toStringAsFixed(1);

                  return GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.pie_chart, color: colorScheme.primary, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  pool.name,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${pool.raidType} • ${pool.diskCount} ${pool.diskCount == 1 ? "Disk" : "Disks"}',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.primary),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: pool.healthy
                                    ? AppColors.healthy.withValues(alpha: 0.15)
                                    : AppColors.critical.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                pool.status,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: pool.healthy ? AppColors.healthy : AppColors.critical,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Used: ${_formatBytes(pool.usableAllocated)} ($percentage%)', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                            Text('Free: ${_formatBytes(pool.usableFree)}', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                            Text('Usable: ${_formatBytes(pool.usableSize)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                          ],
                        ),
                        if (pool.diskNames.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: pool.diskNames.map((d) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(d, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                              );
                            }).toList(),
                          ),
                        ],
                        if (pool.scanFunction != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Last scan: ${pool.scanFunction} (${(pool.scanPercentage ?? 100).toStringAsFixed(1)}%)',
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              // 2. Physical Disks
              ListView.separated(
                padding: EdgeInsets.fromLTRB(16, topPadding, 16, 96),
                itemCount: data.disks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final disk = data.disks[index];
                  final isSsd = disk.type.toUpperCase() == 'SSD';

                  return GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSsd ? AppColors.secondary.withValues(alpha: 0.15) : colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isSsd ? Icons.flash_on : Icons.storage,
                            color: isSsd ? AppColors.secondary : colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    disk.name.toUpperCase(),
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      disk.type,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isSsd ? AppColors.secondary : colorScheme.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${disk.model} • ${_formatBytes(disk.size)}',
                                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (disk.temperature != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: disk.temperature! >= 45 ? AppColors.warning.withValues(alpha: 0.15) : AppColors.healthy.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${disk.temperature!.toStringAsFixed(0)}°C',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: disk.temperature! >= 45 ? AppColors.warning : AppColors.healthy,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

              // 3. Datasets Tree
              ListView.separated(
                padding: EdgeInsets.fromLTRB(16, topPadding, 16, 96),
                itemCount: data.datasets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final ds = data.datasets[index];
                  final depth = ds.id.split('/').length - 1;

                  return Container(
                    margin: EdgeInsets.only(left: (depth * 14.0).clamp(0.0, 48.0)),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          depth == 0 ? Icons.folder_special : Icons.folder_outlined,
                          size: 18,
                          color: depth == 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ds.id,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Used: ${_formatBytes(ds.used)} • Free: ${_formatBytes(ds.available)} • ${ds.compression} (${ds.compressRatio})',
                                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (ds.encrypted)
                          const Icon(Icons.lock_outline, size: 15, color: AppColors.warning),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
