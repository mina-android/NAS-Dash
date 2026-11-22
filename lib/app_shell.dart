import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/landscape_mode_provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_colors.dart';
import 'features/apps/presentation/apps_screen.dart';
import 'features/apps/providers/apps_provider.dart';
import 'features/auth/presentation/onboarding_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/dashboard/providers/telemetry_provider.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/storage/presentation/storage_screen.dart';

final selectedNavigationIndexProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // Safely request notification permission after the Android Activity has mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeServer = ref.watch(activeServerProvider);
    final authState = ref.watch(authStateProvider);
    final isLandscapeLocked = ref.watch(landscapeModeProvider);
    final isLandscape =
        isLandscapeLocked || MediaQuery.of(context).orientation == Orientation.landscape;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // If still loading secure storage, show splash loader
    if (authState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If no server configured, show onboarding wizard
    if (activeServer == null) {
      return OnboardingScreen(
        onCompleted: () {
          ref.read(telemetryProvider.notifier).fetchTelemetry();
        },
      );
    }

    final currentIndex = ref.watch(selectedNavigationIndexProvider);
    final activeAlertCount = ref.watch(
      telemetryProvider.select(
        (asyncTel) =>
            asyncTel.valueOrNull?.alerts
                .where((a) => a['dismissed'] != true)
                .length ??
            0,
      ),
    );
    final appUpdateCount = ref.watch(
      appsProvider.select(
        (asyncApps) =>
            asyncApps.valueOrNull
                ?.where((a) => a.upgradeAvailable)
                .length ??
            0,
      ),
    );

    final destinations = [
      NavDestinationData(
        icon: Icons.space_dashboard_outlined,
        selectedIcon: Icons.space_dashboard_rounded,
        label: 'Dashboard',
        badgeCount: activeAlertCount,
        badgeColor: AppColors.warning,
      ),
      const NavDestinationData(
        icon: Icons.storage_outlined,
        selectedIcon: Icons.storage_rounded,
        label: 'Storage',
      ),
      NavDestinationData(
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view_rounded,
        label: 'Apps',
        badgeCount: appUpdateCount,
        badgeColor: theme.colorScheme.primary,
      ),
      const NavDestinationData(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        label: 'Settings',
      ),
    ];

    const screens = [
      DashboardScreen(),
      StorageScreen(),
      AppsScreen(),
      SettingsScreen(),
    ];

    void selectTab(int index) {
      if (index == currentIndex) return;
      HapticFeedback.selectionClick();
      ref.read(selectedNavigationIndexProvider.notifier).state = index;
    }

    if (isLandscape) {
      return Scaffold(
        body: Row(
          children: [
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.78)
                        : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.88),
                    border: Border(
                      right: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    right: false,
                    child: LandscapeSideNavBar(
                      destinations: destinations,
                      selectedIndex: currentIndex,
                      onDestinationSelected: selectTab,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _FadeIndexedStack(
                index: currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: _FadeIndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.75)
                  : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.85),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedIndex: currentIndex,
              onDestinationSelected: selectTab,
              destinations: destinations
                  .map(
                    (d) => NavigationDestination(
                      icon: _BadgedNavIcon(
                        icon: d.icon,
                        badgeCount: d.badgeCount,
                        badgeColor: d.badgeColor,
                      ),
                      selectedIcon: _BadgedNavIcon(
                        icon: d.selectedIcon,
                        badgeCount: d.badgeCount,
                        badgeColor: d.badgeColor,
                      ),
                      label: d.label,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class NavDestinationData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badgeCount;
  final Color? badgeColor;

  const NavDestinationData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
    this.badgeColor,
  });
}

class _BadgedNavIcon extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final Color? badgeColor;
  final double size;
  final Color? color;

  const _BadgedNavIcon({
    required this.icon,
    required this.badgeCount,
    this.badgeColor,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: size, color: color);
    if (badgeCount <= 0) return iconWidget;
    return Badge.count(
      count: badgeCount,
      backgroundColor: badgeColor ?? Theme.of(context).colorScheme.primary,
      child: iconWidget,
    );
  }
}

class LandscapeSideNavBar extends StatelessWidget {
  final List<NavDestinationData> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const LandscapeSideNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(destinations.length, (index) {
            final dest = destinations[index];
            final isSelected = index == selectedIndex;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: _LandscapeNavTile(
                  destination: dest,
                  isSelected: isSelected,
                  onTap: () => onDestinationSelected(index),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _LandscapeNavTile extends StatelessWidget {
  final NavDestinationData destination;
  final bool isSelected;
  final VoidCallback onTap;

  const _LandscapeNavTile({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = isSelected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.secondaryContainer.withValues(alpha: 0.85)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: 4,
                    height: isSelected ? 34 : 0,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _BadgedNavIcon(
                        icon: isSelected
                            ? destination.selectedIcon
                            : destination.icon,
                        badgeCount: destination.badgeCount,
                        badgeColor: destination.badgeColor,
                        size: 26,
                        color: foregroundColor,
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: foregroundColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _FadeIndexedStack({
    required this.index,
    required this.children,
  });

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1.0,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant _FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: IndexedStack(
        index: widget.index,
        children: widget.children,
      ),
    );
  }
}
