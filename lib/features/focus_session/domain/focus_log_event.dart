/// 로컬 실행 로그 이벤트(서버 없이 추적용).
enum FocusLogEventType {
  focusAttempt, // 시작 버튼 누름
  focusStarted, // 실제 집중 시작(카운트다운 후)
  focusCompleted, // 타이머 완료
  distraction, // 앱 이탈/딴생각 등
  blockCompleted, // 오늘 블록 1개 완료
  notificationShown, // 로컬 알림 표시
  notificationTapped, // 알림 탭
}

class FocusLogEvent {
  FocusLogEvent({
    required this.type,
    required this.tsMs,
    this.dateKey = '',
    this.meta = const {},
  });

  final FocusLogEventType type;
  final int tsMs;

  /// `yyyy-MM-dd` (blockCompleted 등 일자 집계용)
  final String dateKey;

  /// 자유 메타(예: durationSec, quick 등)
  final Map<String, Object?> meta;

  Map<String, Object?> toJson() => {
        'type': type.name,
        'tsMs': tsMs,
        'dateKey': dateKey,
        'meta': meta,
      };

  static FocusLogEvent fromJson(Map<String, Object?> json) {
    final typeName = (json['type'] as String?) ?? FocusLogEventType.distraction.name;
    final type = FocusLogEventType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => FocusLogEventType.distraction,
    );
    return FocusLogEvent(
      type: type,
      tsMs: (json['tsMs'] as num?)?.toInt() ?? 0,
      dateKey: (json['dateKey'] as String?) ?? '',
      meta: (json['meta'] is Map) ? (json['meta'] as Map).cast<String, Object?>() : const {},
    );
  }
}

