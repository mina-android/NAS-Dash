import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kSeenAlertUuidsKey = 'nas_dash_seen_alert_uuids';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse details) {
  if (details.actionId == 'dismiss_alert') {
    final payload = details.payload;
    if (payload != null) {
      try {
        final data = json.decode(payload) as Map<String, dynamic>;
        final uuid = data['uuid'] as String?;
        if (uuid != null) {
          NotificationService.instance.cancelNotificationByUuid(uuid);
        }
      } catch (_) {}
    }
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('ic_notification');
      const initSettings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {},
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // Create high-importance TrueNAS alert channel
      const androidChannel = AndroidNotificationChannel(
        'truenas_alerts_channel',
        'TrueNAS Server Alerts',
        description: 'Notifications for TrueNAS SCALE warnings, hardware alerts, and updates',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error with background handler: $e');
      // Fallback without background response handler
      try {
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidSettings);
        await _plugin.initialize(initSettings);
        const androidChannel = AndroidNotificationChannel(
          'truenas_alerts_channel',
          'TrueNAS Server Alerts',
          description: 'Notifications for TrueNAS SCALE warnings, hardware alerts, and updates',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(androidChannel);
        _isInitialized = true;
      } catch (e2) {
        debugPrint('NotificationService fallback init error: $e2');
      }
    }
  }

  Future<bool> areNotificationsEnabled() async {
    await initialize();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    await initialize();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    } catch (e) {
      debugPrint('NotificationService requestPermissions error: $e');
      return false;
    }
  }

  Future<bool> hasAlertBeenSeen(String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_kSeenAlertUuidsKey) ?? [];
    return seen.contains(uuid);
  }

  Future<void> markAlertSeen(String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_kSeenAlertUuidsKey) ?? [];
    if (!seen.contains(uuid)) {
      seen.add(uuid);
      if (seen.length > 200) seen.removeAt(0);
      await prefs.setStringList(_kSeenAlertUuidsKey, seen);
    }
  }

  Future<void> cancelNotificationByUuid(String uuid) async {
    final id = uuid.hashCode.abs() % 100000;
    await _plugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  Future<void> showAlertNotification({
    required String uuid,
    required String title,
    required String body,
    String level = 'INFO',
    bool force = false,
  }) async {
    await initialize();

    if (!force) {
      final seen = await hasAlertBeenSeen(uuid);
      if (seen) return;
      await markAlertSeen(uuid);
    }

    final id = uuid.hashCode.abs() % 100000;

    final androidDetails = AndroidNotificationDetails(
      'truenas_alerts_channel',
      'TrueNAS Server Alerts',
      channelDescription: 'Notifications for TrueNAS SCALE warnings, hardware alerts, and updates',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
      color: const Color(0xFF0095D5),
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(body),
      actions: const [
        AndroidNotificationAction(
          'dismiss_alert',
          'Dismiss',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: json.encode({'uuid': uuid, 'level': level}),
      );
    } catch (e) {
      debugPrint('NotificationService show error with ic_notification: $e');
      final fallbackDetails = AndroidNotificationDetails(
        'truenas_alerts_channel',
        'TrueNAS Server Alerts',
        channelDescription: 'Notifications for TrueNAS SCALE warnings, hardware alerts, and updates',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        color: const Color(0xFF0095D5),
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(body),
      );
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(android: fallbackDetails),
        payload: json.encode({'uuid': uuid, 'level': level}),
      );
    }
  }
}
