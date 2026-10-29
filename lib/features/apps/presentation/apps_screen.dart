import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/frosted_app_bar.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/refresh_action_button.dart';
import '../../auth/models/server_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/apps_provider.dart';
import 'widgets/app_icon_widget.dart';

class AppsScreen extends ConsumerWidget {
  final bool showBackButton;
  const AppsScreen({super.key, this.showBackButton = false});

  String _resolvePortalUrl(String rawUrl, ServerProfile? profile) {
    if (profile == null) return rawUrl;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return rawUrl;

    if (profile.activeRoute == ActiveRoute.vpn && profile.secondaryHost?.isNotEmpty == true) {
      final vpnUri = Uri.tryParse(profile.normalizedHttpUrl);
      if (vpnUri != null) {
        return uri.replace(host: vpnUri.host).toString();
      }
    }
    return rawUrl;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsState = ref.watch(appsProvider);
    final activeServer = ref.watch(activeServerProvider);
    final notifier = ref.read(appsProvider.notifier);

    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FrostedAppBar(
        title: const Text('Installed TrueNAS Apps'),
        leading: showBackButton ? const BackButton() : null,
        actions: [
          RefreshActionButton(
            onRefresh: () => notifier.fetchApps(),
          ),
        ],
      ),
      body: appsState.when(
        loading: () => Center(child: CircularProgressIndicator(color: colorScheme.primary)),
        error: (err, _) => Center(child: Text('Apps Error: $err', style: const TextStyle(color: AppColors.critical))),
        data: (apps) {
          if (apps.isEmpty) {
            return Center(child: Text('No applications installed.', style: TextStyle(color: colorScheme.onSurfaceVariant)));
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16, topPadding, 16, 96),
            itemCount: apps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final app = apps[index];

              final currentVer = app.humanVersion.isNotEmpty ? app.humanVersion : app.version;
              final nextVer = app.upgradeHumanVersion?.isNotEmpty == true
                  ? app.upgradeHumanVersion!
                  : (app.upgradeVersion?.isNotEmpty == true ? app.upgradeVersion! : null);

              return GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            AppIconWidget(
                              app: app,
                              serverBaseUrl: activeServer?.normalizedHttpUrl,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (app.upgradeAvailable && nextVer != null && nextVer != currentVer)
                                  Row(
                                    children: [
                                      Text(
                                        currentVer,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurfaceVariant,
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
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
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
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                              color: app.isRunning ? AppColors.healthy : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          // Start / Stop toggle
                          OutlinedButton.icon(
                            onPressed: () async {
                              final ok = app.isRunning
                                  ? await notifier.stopApp(app.name)
                                  : await notifier.startApp(app.name);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok ? 'Action dispatched' : 'Action failed'),
                                    backgroundColor: ok ? AppColors.healthy : AppColors.critical,
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              app.isRunning ? Icons.stop : Icons.play_arrow,
                              size: 16,
                              color: app.isRunning ? AppColors.critical : AppColors.healthy,
                            ),
                            label: Text(app.isRunning ? 'Stop' : 'Start'),
                          ),
                          const SizedBox(width: 8),

                          // Upgrade button
                          if (app.upgradeAvailable) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                              onPressed: () async {
                                final ok = await notifier.upgradeApp(app.name);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok ? 'Upgrade started' : 'Upgrade failed'),
                                      backgroundColor: ok ? AppColors.healthy : AppColors.critical,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.arrow_upward, size: 16, color: Colors.black),
                              label: const Text('Upgrade', style: TextStyle(color: Colors.black)),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Portal launcher with NetBird auto-rewriting
                          if (app.portalUrl != null)
                            IconButton(
                              tooltip: 'Open Web UI Portal',
                              icon: const Icon(Icons.open_in_new, color: AppColors.primaryLight),
                              onPressed: () async {
                                final target = _resolvePortalUrl(app.portalUrl!, activeServer);
                                final uri = Uri.parse(target);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
          );
        },
      ),
    );
  }
}
