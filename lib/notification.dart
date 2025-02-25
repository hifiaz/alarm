// ignore_for_file: avoid_print

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// The purpose of this class is to show a notification to the user
/// when the alarm rings so the user can understand where the audio
/// come from. He also can tap the notification to open directly the app.
class Notification {
  Notification._();

  static final instance = Notification._();

  /// A unique identifier because it can be only one alarm.
  static const alarmId = 888;
  final FlutterLocalNotificationsPlugin localNotif =
      FlutterLocalNotificationsPlugin();

  /// Add configuration for local notifications and initialize.
  Future<void> init() async {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await localNotif.initialize(initializationSettings);
    tz.initializeTimeZones();
  }

  /// Show notification permission request.
  Future<bool> requestPermission() async {
    final result = await localNotif
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    return result ?? false;
  }

  tz.TZDateTime nextInstanceOfTime(Time time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      ),
      tz.local,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Schedule notification for iOS at the given time.
  Future<void> scheduleIOSAlarmNotif({
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentSound: false,
      presentAlert: false,
      presentBadge: false,
    );
    const platformChannelSpecifics = NotificationDetails(
      iOS: iOSPlatformChannelSpecifics,
    );

    final zdt = nextInstanceOfTime(Time(dateTime.hour, dateTime.minute));

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      print("[Alarm] Notification permission denied");
      return;
    }

    try {
      await localNotif.zonedSchedule(
        alarmId,
        title,
        body,
        zdt,
        platformChannelSpecifics,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print("[Alarm] Notification scheduled successfuly at ${zdt.toString()}");
    } catch (e) {
      print("[Alarm] Schedule notification error: $e");
    }
  }

  /// Show notification for Android instantly.
  Future<void> androidAlarmNotif({
    required String title,
    required String body,
  }) async {
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'alarm',
      'alarm',
      channelDescription: 'Alarm package',
      importance: Importance.max,
      priority: Priority.max,
      enableLights: true,
      playSound: false,
    );

    const platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await localNotif.show(
      alarmId,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  /// Cancel notification. Called when the alarm is cancelled.
  Future<void> cancel() => localNotif.cancel(alarmId);
}
