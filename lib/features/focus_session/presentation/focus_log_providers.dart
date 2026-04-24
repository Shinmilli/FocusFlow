import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_focus_log_repository.dart';
import '../domain/focus_log_event.dart';

final focusLogRepositoryProvider = Provider<LocalFocusLogRepository>((ref) {
  return LocalFocusLogRepository();
});

final focusLogEventsProvider = FutureProvider<List<FocusLogEvent>>((ref) async {
  final repo = ref.watch(focusLogRepositoryProvider);
  return repo.loadAll();
});

class DerivedSessionSignals {
  const DerivedSessionSignals({
    required this.minutesToStart,
    required this.ignoredNotifications,
    required this.distractionCountToday,
  });

  final int minutesToStart;
  final int ignoredNotifications;
  final int distractionCountToday;
}

String _todayKey() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

final derivedSignalsProvider = FutureProvider<DerivedSessionSignals>((ref) async {
  final events = await ref.watch(focusLogEventsProvider.future);
  final today = _todayKey();

  // minutesToStart: 최근 attempt -> started 간 차이(없으면 0)
  final attempt = events.lastWhere(
    (e) => e.type == FocusLogEventType.focusAttempt,
    orElse: () => FocusLogEvent(type: FocusLogEventType.focusAttempt, tsMs: 0),
  );
  final started = events.lastWhere(
    (e) => e.type == FocusLogEventType.focusStarted,
    orElse: () => FocusLogEvent(type: FocusLogEventType.focusStarted, tsMs: 0),
  );
  var minutesToStart = 0;
  if (attempt.tsMs > 0 && started.tsMs >= attempt.tsMs) {
    minutesToStart = ((started.tsMs - attempt.tsMs) / 60000).round();
  }

  final distractionsToday = events.where((e) {
    if (e.type != FocusLogEventType.distraction) return false;
    return e.dateKey == today;
  }).length;

  final shownToday = events.where((e) {
    if (e.type != FocusLogEventType.notificationShown) return false;
    return e.dateKey == today;
  }).length;
  final tappedToday = events.where((e) {
    if (e.type != FocusLogEventType.notificationTapped) return false;
    return e.dateKey == today;
  }).length;

  // 최소 구현: 오늘 "표시 - 탭"을 무시로 간주. (0 미만 방지)
  var ignored = shownToday - tappedToday;
  if (ignored < 0) ignored = 0;

  // 아직 알림을 한 번도 안 쓰는 경우엔 기존 proxy(이탈)로 fallback
  if (shownToday == 0) {
    ignored = distractionsToday;
  }

  return DerivedSessionSignals(
    minutesToStart: minutesToStart,
    ignoredNotifications: ignored,
    distractionCountToday: distractionsToday,
  );
});

