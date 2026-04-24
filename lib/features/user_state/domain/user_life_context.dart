/// 오늘 컨디션·환경. AI가 계획 강도·개입을 조절할 때 사용.
class UserLifeContext {
  const UserLifeContext({
    this.sleepHours = 7,
    this.stressLevel = 3,
    this.phoneHeavyUse = false,
    this.examPeriod = false,
    this.burnoutRisk = false,
    this.moodNote = '',
  });

  final double sleepHours;
  /// 1–5 가정
  final int stressLevel;
  final bool phoneHeavyUse;
  final bool examPeriod;
  final bool burnoutRisk;
  final String moodNote;

  /// 0.5 ~ 1.5 — 계획 강도 승수(낮을수록 오늘은 적게).
  double get planIntensityMultiplier {
    var m = 1.0;
    if (sleepHours < 5) m -= 0.25;
    if (sleepHours < 6.5) m -= 0.1;
    if (stressLevel >= 4) m -= 0.15;
    if (phoneHeavyUse) m -= 0.1;
    if (examPeriod && sleepHours < 6) m -= 0.1;
    if (burnoutRisk) m -= 0.2;
    return m.clamp(0.5, 1.5);
  }

  UserLifeContext copyWith({
    double? sleepHours,
    int? stressLevel,
    bool? phoneHeavyUse,
    bool? examPeriod,
    bool? burnoutRisk,
    String? moodNote,
  }) {
    return UserLifeContext(
      sleepHours: sleepHours ?? this.sleepHours,
      stressLevel: stressLevel ?? this.stressLevel,
      phoneHeavyUse: phoneHeavyUse ?? this.phoneHeavyUse,
      examPeriod: examPeriod ?? this.examPeriod,
      burnoutRisk: burnoutRisk ?? this.burnoutRisk,
      moodNote: moodNote ?? this.moodNote,
    );
  }
}
