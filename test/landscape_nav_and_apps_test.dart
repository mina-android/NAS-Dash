import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nasdash/app_shell.dart';
import 'package:nasdash/core/network/truenas_http_client.dart';
import 'package:nasdash/core/providers/landscape_mode_provider.dart';
import 'package:nasdash/features/apps/models/app_model.dart';
import 'package:nasdash/features/apps/presentation/apps_screen.dart';
import 'package:nasdash/features/apps/providers/apps_provider.dart';
import 'package:nasdash/features/auth/models/server_profile.dart';
import 'package:nasdash/features/auth/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoOpHttpClient implements TruenasHttpClient {
  @override
  ServerProfile? get profile => null;

  @override
  Ref<Object?> get ref => throw UnimplementedError();

  @override
  late Dio dio = Dio();

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) async =>
      Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200);

  @override
  Future<Response<T>> post<T>(String path, {dynamic data}) async =>
      Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200);

  @override
  Future<Response<T>> put<T>(String path, {dynamic data}) async =>
      Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200);

  @override
  Future<Response<T>> delete<T>(String path, {dynamic data}) async =>
      Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200);
}

class _FakeAppsNotifier extends AppsNotifier {
  final List<TrueNasApp> _initial;

  _FakeAppsNotifier(this._initial) : super(_NoOpHttpClient()) {
    state = AsyncValue.data(_initial);
  }

  @override
  Future<void> fetchApps() async {
    state = AsyncValue.data(_initial);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LandscapeSideNavBar stretches 4 destinations evenly across full rail height and shows badges',
      (tester) async {
    int tappedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(left: 44)),
          child: Scaffold(
            body: SizedBox(
              height: 400,
              child: SafeArea(
                right: false,
                child: LandscapeSideNavBar(
                  selectedIndex: 0,
                  onDestinationSelected: (i) => tappedIndex = i,
                  destinations: const [
                    NavDestinationData(
                      icon: Icons.space_dashboard_outlined,
                      selectedIcon: Icons.space_dashboard_rounded,
                      label: 'Dashboard',
                      badgeCount: 3,
                    ),
                    NavDestinationData(
                      icon: Icons.storage_outlined,
                      selectedIcon: Icons.storage_rounded,
                      label: 'Storage',
                    ),
                    NavDestinationData(
                      icon: Icons.grid_view_outlined,
                      selectedIcon: Icons.grid_view_rounded,
                      label: 'Apps',
                      badgeCount: 2,
                    ),
                    NavDestinationData(
                      icon: Icons.settings_outlined,
                      selectedIcon: Icons.settings_rounded,
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Inner rail preserves full 116dp width even with 44dp left display cutout
    expect(tester.getSize(find.byType(LandscapeSideNavBar)).width, equals(116));

    // Each of the 4 Expanded tiles should stretch to ~90px (400 / 4 minus small padding)
    final inkWellSizes = tester
        .widgetList<InkWell>(find.byType(InkWell))
        .map((w) => tester.getSize(find.byWidget(w)).height)
        .toList();
    expect(inkWellSizes.length, equals(4));
    for (final h in inkWellSizes) {
      expect(h, greaterThan(85));
      expect(h, closeTo(inkWellSizes.first, 1.0));
    }

    // Badges render active counts
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Apps'));
    expect(tappedIndex, equals(2));
  });

  testWidgets('AppsScreen search bar and status filter chips filter apps accurately', (tester) async {
    final sampleApps = [
      TrueNasApp(
        id: 'plex',
        name: 'plex',
        state: 'RUNNING',
        version: '1.40.5',
        humanVersion: '1.40.5',
        upgradeAvailable: true,
        upgradeHumanVersion: '1.41.0',
      ),
      TrueNasApp(
        id: 'pihole',
        name: 'pihole',
        state: 'STOPPED',
        version: '2024.07',
        humanVersion: '2024.07',
        upgradeAvailable: false,
      ),
      TrueNasApp(
        id: 'immich',
        name: 'immich',
        state: 'RUNNING',
        version: '1.118.0',
        humanVersion: '1.118.0',
        upgradeAvailable: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appsProvider.overrideWith((ref) => _FakeAppsNotifier(sampleApps)),
          activeServerProvider.overrideWithValue(null),
          landscapeModeProvider.overrideWith((ref) => LandscapeModeNotifier(applyPlatformEffects: false)),
        ],
        child: const MaterialApp(
          home: AppsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('Running (2)'), findsOneWidget);
    expect(find.text('Stopped (1)'), findsOneWidget);
    expect(find.text('Updates (1)'), findsOneWidget);

    // Filter to Stopped
    await tester.tap(find.text('Stopped (1)'));
    await tester.pump();
    expect(find.text('pihole'), findsOneWidget);
    expect(find.text('plex'), findsNothing);
    expect(find.text('immich'), findsNothing);

    // Filter to Updates
    await tester.tap(find.text('Updates (1)'));
    await tester.pump();
    expect(find.text('plex'), findsOneWidget);
    expect(find.text('pihole'), findsNothing);

    // Back to All + search
    await tester.tap(find.text('All (3)'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'imm');
    await tester.pump();
    expect(find.text('immich'), findsOneWidget);
    expect(find.text('plex'), findsNothing);

    // Non-matching search shows empty state & Clear filters resets
    await tester.enterText(find.byType(TextField), 'nonexistent');
    await tester.pump();
    expect(find.text('No apps match your filter.'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pump();
    expect(find.text('plex'), findsOneWidget);
    expect(find.text('pihole'), findsOneWidget);
    expect(find.text('immich'), findsOneWidget);
  });
}
