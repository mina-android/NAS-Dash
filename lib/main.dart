import 'dart:io';
import 'dart:ui';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'app_shell.dart';
import 'core/network/truenas_ws_client.dart';
import 'core/services/background_alert_worker.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

class _TrueNasHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TrueNasHttpOverrides();

  // Setup Global Error Handlers to prevent silent black screen crashes
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught Platform error: $error\n$stack');
    return true; // Mark as handled
  };

  // Safe global fallback widget for render exceptions
  ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 54, color: Colors.amber),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  errorDetails.exceptionAsString(),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  // Asynchronously initialize background services without blocking UI startup
  _initBackgroundServices();

  runApp(
    const ProviderScope(
      child: NasDashApp(),
    ),
  );
}

void _initBackgroundServices() async {
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Background NotificationService init error: $e');
  }

  try {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    Workmanager().registerPeriodicTask(
      kAlertCheckPeriodicTask,
      'alertCheckPeriodicTask',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  } catch (e) {
    debugPrint('Background Workmanager init error: $e');
  }
}

class NasDashApp extends ConsumerWidget {
  const NasDashApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly connect WebSocket for foreground alerts
    ref.watch(truenasWsClientProvider);
    final themeSettings = ref.watch(themeSettingsProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightScheme = themeSettings.useDynamicColors ? lightDynamic : null;
        final darkScheme = themeSettings.useDynamicColors ? darkDynamic : null;

        return MaterialApp(
          title: 'NAS Dash',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(lightScheme),
          darkTheme: AppTheme.darkTheme(darkScheme),
          themeMode: themeSettings.themeMode,
          home: const AppShell(),
        );
      },
    );
  }
}
