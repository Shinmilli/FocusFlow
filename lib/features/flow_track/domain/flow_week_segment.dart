class FlowWeekSegment {
  const FlowWeekSegment({
    required this.weekKey,
    required this.weekStartDateKey,
    required this.weeklyTarget,
    required this.completedCount,
    required this.success,
    required this.streakWeeks,
    required this.masteryGauge,
    required this.tier,
    required this.repairMark,
    required this.updatedAtMs,
  });

  final String weekKey; // YYYY-WW (ISO week)
  final String weekStartDateKey; // yyyy-MM-dd (Monday)
  final int weeklyTarget;
  final int completedCount;
  final bool success;
  final int streakWeeks;
  final double masteryGauge; // 0..1
  final String tier;
  final bool repairMark;
  final int updatedAtMs;

  Map<String, Object?> toJson() => {
        'weekKey': weekKey,
        'weekStartDateKey': weekStartDateKey,
        'weeklyTarget': weeklyTarget,
        'completedCount': completedCount,
        'success': success,
        'streakWeeks': streakWeeks,
        'masteryGauge': masteryGauge,
        'tier': tier,
        'repairMark': repairMark,
        'updatedAtMs': updatedAtMs,
      };

  static FlowWeekSegment fromJson(Map<String, Object?> json) {
    return FlowWeekSegment(
      weekKey: json['weekKey'] as String,
      weekStartDateKey: (json['weekStartDateKey'] as String?) ?? '',
      weeklyTarget: (json['weeklyTarget'] as num?)?.toInt() ?? 5,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      success: (json['success'] as bool?) ?? false,
      streakWeeks: (json['streakWeeks'] as num?)?.toInt() ?? 0,
      masteryGauge: (json['masteryGauge'] as num?)?.toDouble() ?? 0,
      tier: (json['tier'] as String?) ?? 'Iron',
      repairMark: (json['repairMark'] as bool?) ?? false,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  FlowWeekSegment copyWith({
    int? weeklyTarget,
    int? completedCount,
    bool? success,
    int? streakWeeks,
    double? masteryGauge,
    String? tier,
    bool? repairMark,
    int? updatedAtMs,
  }) {
    return FlowWeekSegment(
      weekKey: weekKey,
      weekStartDateKey: weekStartDateKey,
      weeklyTarget: weeklyTarget ?? this.weeklyTarget,
      completedCount: completedCount ?? this.completedCount,
      success: success ?? this.success,
      streakWeeks: streakWeeks ?? this.streakWeeks,
      masteryGauge: masteryGauge ?? this.masteryGauge,
      tier: tier ?? this.tier,
      repairMark: repairMark ?? this.repairMark,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }
}

