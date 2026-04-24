import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../focus_session/domain/focus_log_event.dart';
import '../../focus_session/presentation/focus_log_providers.dart';
import '../data/daily_reminder_prefs.dart';
import '../data/local_notification_service.dart';

final localNotificationsPluginProvider = Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

final localNotificationServiceProvider = Provider<LocalNotificationService>((ref) {
  return LocalNotificationService(ref.watch(localNotificationsPluginProvider));
});

/// 앱 시작 시 1회: 권한/탭 콜백/저장된 매일 리마인더 재등록.
final notificationInitProvider = FutureProvider<void>((ref) async {
  final svc = ref.read(localNotificationServiceProvider);
  await svc.ensureInitialized(
    onTap: (payload) {
      final now = DateTime.now();
      final dateKey =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      ref.read(notificationTapProvider.notifier).state = payload;
      ref.read(focusLogRepositoryProvider).append(
            FocusLogEvent(
              type: FocusLogEventType.notificationTapped,
              tsMs: now.millisecondsSinceEpoch,
              dateKey: dateKey,
              meta: {'payload': payload ?? ''},
            ),
          );
      ref.invalidate(focusLogEventsProvider);
    },
  );

  final dr = await DailyReminderPrefs.load();
  if (dr.enabled) {
    await svc.scheduleDailyReminder(hour: dr.hour, minute: dr.minute);
  } else {
    await svc.cancelDailyReminder();
  }
});

final notificationTapProvider = StateProvider<String?>((ref) => null);

final dailyReminderStateProvider = FutureProvider<DailyReminderState>((ref) async {
  return DailyReminderPrefs.load();
});

Future<void> applyDailyReminder(WidgetRef ref, DailyReminderState next) async {
  await DailyReminderPrefs.save(next);
  ref.invalidate(dailyReminderStateProvider);

  await ref.read(notificationInitProvider.future);
  final svc = ref.read(localNotificationServiceProvider);
  if (next.enabled) {
    await svc.cancelDailyReminder();
    await svc.scheduleDailyReminder(hour: next.hour, minute: next.minute);
  } else {
    await svc.cancelDailyReminder();
  }
}

/// 알림 테스트: 표시/탭/무시(표시만 되고 탭 없으면) 추적을 위한 최소 기능.
Future<void> showTestReminder(WidgetRef ref) async {
  await ref.read(notificationInitProvider.future);
  final svc = ref.read(localNotificationServiceProvider);
  final now = DateTime.now();
  final dateKey =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  await ref.read(focusLogRepositoryProvider).append(
        FocusLogEvent(
          type: FocusLogEventType.notificationShown,
          tsMs: now.millisecondsSinceEpoch,
          dateKey: dateKey,
          meta: {'kind': 'test'},
        ),
      );
  ref.invalidate(focusLogEventsProvider);

  await svc.showReminder(
    id: 1001,
    title: 'FocusFlow',
    body: '딱 1단계만 시작해볼까요?',
    payload: 'test',
  );
}
