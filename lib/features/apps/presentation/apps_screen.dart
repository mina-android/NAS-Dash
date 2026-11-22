import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/landscape_mode_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/frosted_app_bar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/refresh_action_button.dart';
import '../../../core/widgets/responsive_two_column_grid.dart';
import '../../auth/models/server_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/app_model.dart';
import '../providers/apps_provider.dart';
import 'widgets/app_icon_widget.dart';

enum AppFilterMode { all, running, stopped, updates }

class AppsScreen extends ConsumerStatefulWidget {
  final bool showBackButton;
  const AppsScreen({super.key, this.showBackButton = false});

  @override
  ConsumerState<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends ConsumerState<AppsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  AppFilterMode _filterMode = AppFilterMode.all;
  bool _isBatchUpgrading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TrueNasApp> _applyFilters(List<TrueNasApp> apps) {
    final query = _searchQuery.trim().toLowerCase();
    return apps.where((app) {
      final matchesFilter = switch (_filterMode) {
        AppFilterMode.all => true,
        AppFilterMode.running => app.isRunning,
        AppFilterMode.stopped => !app.isRunning,
        AppFilterMode.updates => app.upgradeAvailable,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return app.name.toLowerCase().contains(query) ||
          app.humanVersion.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildFilterHeader(
    List<TrueNasApp> apps,
    AppsNotifier notifier,
    ColorScheme colorScheme,
  ) {
    final runningCount = apps.where((a) => a.isRunning).length;
    final stoppedCount = apps.length - runningCount;
    final upgradeableApps = apps.where((a) => a.upgradeAvailable).toList();
    final updatesCount = upgradeableApps.length;

    final chips = <(AppFilterMode, String)>[
      (AppFilterMode.all, 'All (${apps.length})'),
      (AppFilterMode.running, 'Running ($runningCount)'),
      (AppFilterMode.stopped, 'Stopped ($stoppedCount)'),
      (AppFilterMode.updates, 'Updates ($updatesCount)'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search apps or version...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...chips.map((entry) {
                final mode = entry.$1;
                final label = entry.$2;
                final selected = _filterMode == mode;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    onSelected: (_) => setState(() => _filterMode = mode),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }),
              if (updatesCount > 0)
                ActionChip(
                  avatar: _isBatchUpgrading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(
                          Icons.system_update_alt_rounded,
                          size: 16,
                          color: Colors.black,
                        ),
                  label: Text(
                    _isBatchUpgrading
                        ? 'Upgrading...'
                        : 'Upgrade All ($updatesCount)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  backgroundColor: AppColors.warning,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: _isBatchUpgrading
                      ? null
                      : () async {
                          setState(() => _isBatchUpgrading = true);
                          try {
                            final res = await notifier.upgradeAllApps(
                              upgradeableApps.map((a) => a.name).toList(),
                            );
                            if (mounted) {
                              final message = res.failed == 0
                                  ? 'Upgraded ${res.succeeded} app${res.succeeded == 1 ? '' : 's'}'
                                  : 'Upgraded ${res.succeeded}, failed ${res.failed}: ${res.errors.first}';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: res.failed == 0
                                      ? AppColors.healthy
                                      : AppColors.critical,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isBatchUpgrading = false);
                            }
                          }
                        },
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _resolvePortalUrl(String rawUrl, ServerProfile? profile) {
    if (profile == null) return rawUrl;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return rawUrl;

    if (profile.activeRoute == ActiveRoute.vpn &&
        profile.secondaryHost?.isNotEmpty == true) {
      final vpnUri = Uri.tryParse(profile.normalizedHttpUrl);
      if (vpnUri != null) {
        return uri.replace(host: vpnUri.host).toString();
      }
    }
    return rawUrl;
  }

  Widget _buildAppCard(
    BuildContext context,
    TrueNasApp app,
    ServerProfile? activeServer,
    AppsNotifier notifier,
    ColorScheme colorScheme,
    AppJobProgress? activeJob,
  ) {
    final currentVer =
        app.humanVersion.isNotEmpty ? app.humanVersion : app.version;
    final nextVer = app.upgradeHumanVersion?.isNotEmpty == true
        ? app.upgradeHumanVersion!
        : (app.upgradeVersion?.isNotEmpty == true ? app.upgradeVersion! : null);
    final isBusy = activeJob != null;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    AppIconWidget(
                      app: app,
                      serverBaseUrl: activeServer?.normalizedHttpUrl,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (app.upgradeAvailable &&
                              nextVer != null &&
                              nextVer != currentVer)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    currentVer,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 11,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: AppColors.warning
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    nextVer,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              currentVer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: app.isRunning
                      ? AppColors.healthy.withValues(alpha: 0.15)
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  app.state,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: app.isRunning
                        ? AppColors.healthy
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Start / Stop toggle
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () async {
                        final result = app.isRunning
                            ? await notifier.stopApp(app.name)
                            : await notifier.startApp(app.name);
                        if (context.mounted) {
                          final actionWord = app.isRunning ? 'Stop' : 'Start';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.ok
                                    ? '$actionWord completed'
                                    : '$actionWord failed: ${result.errorMessage ?? 'Unknown error'}',
                              ),
                              backgroundColor: result.ok
                                  ? AppColors.healthy
                                  : AppColors.critical,
                            ),
                          );
                        }
                      },
                icon: Icon(
                  app.isRunning ? Icons.stop : Icons.play_arrow,
                  size: 16,
                  color:
                      app.isRunning ? AppColors.critical : AppColors.healthy,
                ),
                label: Text(app.isRunning ? 'Stop' : 'Start'),
              ),

              // Upgrade button
              if (app.upgradeAvailable)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    disabledBackgroundColor:
                        AppColors.warning.withValues(alpha: 0.65),
                  ),
                  onPressed: isBusy
                      ? null
                      : () async {
                          final result = await notifier.upgradeApp(app.name);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.ok
                                      ? '${app.name} upgraded successfully'
                                      : 'Upgrade failed: ${result.errorMessage ?? 'Unknown error'}',
                                ),
                                backgroundColor: result.ok
                                    ? AppColors.healthy
                                    : AppColors.critical,
                              ),
                            );
                          }
                        },
                  icon: (isBusy && activeJob.action == 'Upgrading')
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.arrow_upward,
                          size: 16, color: Colors.black),
                  label: Text(
                    (isBusy && activeJob.action == 'Upgrading')
                        ? (activeJob.percent != null
                            ? 'Upgrading ${activeJob.percent!.round()}%'
                            : 'Upgrading...')
                        : 'Upgrade',
                    style: const TextStyle(color: Colors.black),
                  ),
                ),

              if (isBusy && activeJob.action != 'Upgrading')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      activeJob.percent != null
                          ? '${activeJob.action} ${activeJob.percent!.round()}%'
                          : '${activeJob.action}...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

              // Portal launcher with NetBird auto-rewriting
              if (app.portalUrl != null)
                IconButton(
                  tooltip: 'Open Web UI Portal',
                  icon: const Icon(Icons.open_in_new,
                      color: AppColors.primaryLight),
                  onPressed: () async {
                    final target =
                        _resolvePortalUrl(app.portalUrl!, activeServer);
                    final uri = Uri.parse(target);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appsState = ref.watch(appsProvider);
    final activeJobs = ref.watch(activeAppJobsProvider);
    final activeServer = ref.watch(activeServerProvider);
    final notifier = ref.read(appsProvider.notifier);
    final isLandscapeLocked = ref.watch(landscapeModeProvider);
    final isLandscape =
        isLandscapeLocked || MediaQuery.of(context).orientation == Orientation.landscape;

    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    final bottomPadding = isLandscape ? 24.0 : 96.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FrostedAppBar(
        title: const Text('Installed TrueNAS Apps'),
        leading: widget.showBackButton ? const BackButton() : null,
        actions: [
          RefreshActionButton(
            onRefresh: () => notifier.fetchApps(),
          ),
        ],
      ),
      body: appsState.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: colorScheme.primary)),
        error: (err, _) => Center(
            child: Text('Apps Error: $err',
                style: const TextStyle(color: AppColors.critical))),
        data: (apps) {
          if (apps.isEmpty) {
            return Center(
                child: Text('No applications installed.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)));
          }

          final filteredApps = _applyFilters(apps);
          final listPadding = EdgeInsets.fromLTRB(16, 12, 16, bottomPadding);

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, topPadding, 16, 0),
                child: _buildFilterHeader(apps, notifier, colorScheme),
              ),
              Expanded(
                child: filteredApps.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 40,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No apps match your filter.',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _filterMode = AppFilterMode.all;
                                });
                              },
                              child: const Text('Clear filters'),
                            ),
                          ],
                        ),
                      )
                    : (isLandscape
                        ? UniformTwoColumnGrid(
                            padding: listPadding,
                            itemCount: filteredApps.length,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            itemBuilder: (context, index) {
                              final app = filteredApps[index];
                              return _buildAppCard(
                                context,
                                app,
                                activeServer,
                                notifier,
                                colorScheme,
                                activeJobs[app.name],
                              );
                            },
                          )
                        : ListView.separated(
                            padding: listPadding,
                            itemCount: filteredApps.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final app = filteredApps[index];
                              return _buildAppCard(
                                context,
                                app,
                                activeServer,
                                notifier,
                                colorScheme,
                                activeJobs[app.name],
                              );
                            },
                          )),
              ),
            ],
          );
        },
      ),
    );
  }
}
