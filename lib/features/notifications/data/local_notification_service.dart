import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  LocalNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const int dailyReminderNotificationId = 2001;

  Future<void>? _initFuture;

  Future<void> ensureInitialized({
    void Function(String? payload)? onTap,
  }) {
    _initFuture ??= _doInit(onTap: onTap);
    return _initFuture!;
  }

  Future<void> _doInit({
    void Function(String? payload)? onTap,
  }) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: android,
      iOS: darwin,
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        onTap?.call(resp.payload);
      },
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> showReminder({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'focusflow_reminders',
      'FocusFlow Reminders',
      channelDescription: 'FocusFlow 실행 유도 알림',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// 매일 같은 시각에 반복(기기 로컬). 재부팅 후에는 앱을 한 번 열어야 다시 잡힐 수 있음(MVP).
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    String payload = 'daily',
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'focusflow_reminders',
      'FocusFlow Reminders',
      channelDescription: 'FocusFlow 실행 유도 알림',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      dailyReminderNotificationId,
      'FocusFlow',
      '오늘 블록 확인 후, 딱 1단계만 시작해볼까요?',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(dailyReminderNotificationId);
  }
}
