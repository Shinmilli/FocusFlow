/// XP, 레벨, 스트릭, 배지(확장용).
class PlayerProgress {
  const PlayerProgress({
    this.xp = 0,
    this.level = 1,
    this.streakDays = 0,
    this.badges = const [],
    this.lastStreakDateKey = '',
    this.totalBlocksCompleted = 0,
  });

  final int xp;
  final int level;
  final int streakDays;
  final List<String> badges;
  final String lastStreakDateKey;

  /// 누적 완료 블록 수(배지·통계용).
  final int totalBlocksCompleted;

  static int xpForLevel(int level) => level * 100;

  PlayerProgress addXp(int delta) {
    var x = xp + delta;
    var lv = level;
    while (x >= xpForLevel(lv)) {
      x -= xpForLevel(lv);
      lv++;
    }
    return PlayerProgress(
      xp: x,
      level: lv,
      streakDays: streakDays,
      badges: badges,
      lastStreakDateKey: lastStreakDateKey,
      totalBlocksCompleted: totalBlocksCompleted,
    );
  }

  PlayerProgress withStreak(int days) {
    return PlayerProgress(
      xp: xp,
      level: level,
      streakDays: days,
      badges: badges,
      lastStreakDateKey: lastStreakDateKey,
      totalBlocksCompleted: totalBlocksCompleted,
    );
  }

  PlayerProgress withStreakMeta({required int days, required String lastDateKey}) {
    return PlayerProgress(
      xp: xp,
      level: level,
      streakDays: days,
      badges: badges,
      lastStreakDateKey: lastDateKey,
      totalBlocksCompleted: totalBlocksCompleted,
    );
  }

  PlayerProgress unlockBadge(String id) {
    if (badges.contains(id)) return this;
    return PlayerProgress(
      xp: xp,
      level: level,
      streakDays: streakDays,
      badges: [...badges, id],
      lastStreakDateKey: lastStreakDateKey,
      totalBlocksCompleted: totalBlocksCompleted,
    );
  }

  PlayerProgress withTotalBlocksIncremented() {
    return PlayerProgress(
      xp: xp,
      level: level,
      streakDays: streakDays,
      badges: badges,
      lastStreakDateKey: lastStreakDateKey,
      totalBlocksCompleted: totalBlocksCompleted + 1,
    );
  }

  Map<String, Object?> toJson() => {
        'xp': xp,
        'level': level,
        'streakDays': streakDays,
        'badges': badges,
        'lastStreakDateKey': lastStreakDateKey,
        'totalBlocksCompleted': totalBlocksCompleted,
      };

  static PlayerProgress fromJson(Map<String, Object?> json) {
    return PlayerProgress(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
      badges: (json['badges'] as List?)?.whereType<String>().toList() ?? const [],
      lastStreakDateKey: (json['lastStreakDateKey'] as String?) ?? '',
      totalBlocksCompleted: (json['totalBlocksCompleted'] as num?)?.toInt() ?? 0,
    );
  }
}
