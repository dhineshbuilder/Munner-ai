import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const String channelId = 'munner_workout_alarm_v2';
  static const String channelName = 'Workout Alarms & Reminders';
  static const String channelDescription =
      'High-priority alarms and reminders for daily workout routines';

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize Timezones for accurate scheduled alarms
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification tapped with payload: ${response.payload}");
      },
    );

    // Create high-importance Android notification channel with custom alarm sound
    if (!kIsWeb && Platform.isAndroid) {
      final AndroidNotificationChannel channel = const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('alarm'),
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    _isInitialized = true;
  }

  /// Request runtime permissions on Android 13+ and iOS
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted =
          await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      final bool? granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  /// Schedule exact alarms for specific days of the week (1=Mon ... 7=Sun)
  Future<void> scheduleWeeklyWorkoutAlarms({
    required int hour,
    required int minute,
    required List<int> days,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await cancelAllAlarms();

    final androidDetails = const AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('alarm'),
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        "Time to work out! Stay consistent, follow your routine, and keep your streak alive.",
        contentTitle: "⏰ Workout Time — MunnerAI",
        summaryText: "Daily Fitness Reminder",
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      sound: 'alarm.mp3',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule for each selected day (IDs 101 to 107)
    for (final day in days) {
      final int notificationId = 100 + day;
      final tz.TZDateTime scheduledDate = _nextInstanceOfDayAndTime(day, hour, minute);

      try {
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          "⏰ Workout Time — MunnerAI",
          "Time for today's workout! Tap to start your session.",
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'workout_alarm',
        );
        debugPrint(
            "Scheduled alarm for Day $day at $hour:$minute (Next: $scheduledDate)");
      } catch (e) {
        debugPrint("Error scheduling alarm for Day $day: $e");
      }
    }
  }

  /// Show an instant test notification with sound and vibration
  Future<void> showTestAlarmNotification() async {
    if (kIsWeb) return;
    await initialize();
    await requestPermissions();

    final androidDetails = const AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('alarm'),
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      sound: 'alarm.mp3',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      999,
      "⏰ Test Workout Alarm — MunnerAI",
      "System alarm is working properly even on lock screen!",
      notificationDetails,
      payload: 'test_alarm',
    );
  }

  /// Cancel all scheduled alarms
  Future<void> cancelAllAlarms() async {
    if (kIsWeb) return;
    for (int i = 101; i <= 107; i++) {
      await _notificationsPlugin.cancel(i);
    }
  }

  /// Compute the next instance of a specific weekday and time
  tz.TZDateTime _nextInstanceOfDayAndTime(int targetDay, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If today is targetDay and scheduled time already passed today, advance by 7 days
    while (scheduledDate.weekday != targetDay || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
