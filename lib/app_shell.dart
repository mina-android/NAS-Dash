import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/notification_service.dart';
import 'features/apps/presentation/apps_screen.dart';
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

    const screens = [
      DashboardScreen(),
      StorageScreen(),
      AppsScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
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
              onDestinationSelected: (index) {
                ref.read(selectedNavigationIndexProvider.notifier).state = index;
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storage_outlined),
                  selectedIcon: Icon(Icons.storage),
                  label: 'Storage',
                ),
                NavigationDestination(
                  icon: Icon(Icons.apps_outlined),
                  selectedIcon: Icon(Icons.apps),
                  label: 'Apps',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
