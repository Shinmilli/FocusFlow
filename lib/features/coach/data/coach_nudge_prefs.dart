import 'package:shared_preferences/shared_preferences.dart';

import '../../planning/presentation/planning_providers.dart';

enum CoachNudgeType {
  aiTodayPlan,
  bodyDoubling,
  insightsSummary,
  failurePattern,
}

enum CoachNudgeIntensity {
  light,
  active,
}

class CoachNudgePrefs {
  CoachNudgePrefs({SharedPreferences? prefs})
      : _prefsFuture = prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;

  static const _kIntensity = 'coach.intensity.v1';
  static const _kHiddenUntilPrefix = 'coach.hiddenUntil.'; // + type
  static const _kLastShownDatePrefix = 'coach.lastShownDate.'; // + type

  Future<CoachNudgeIntensity> intensity() async {
    final p = await _prefsFuture;
    final raw = p.getString(_kIntensity) ?? CoachNudgeIntensity.active.name;
    return CoachNudgeIntensity.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => CoachNudgeIntensity.active,
    );
  }

  Future<void> setIntensity(CoachNudgeIntensity v) async {
    final p = await _prefsFuture;
    await p.setString(_kIntensity, v.name);
  }

  Future<String> hiddenUntilDateKey(CoachNudgeType type) async {
    final p = await _prefsFuture;
    return p.getString('$_kHiddenUntilPrefix${type.name}') ?? '';
  }

  Future<void> hideForDays(CoachNudgeType type, int days) async {
    final p = await _prefsFuture;
    final now = DateTime.now();
    final until = now.add(Duration(days: days));
    final key = '${until.year.toString().padLeft(4, '0')}-'
        '${until.month.toString().padLeft(2, '0')}-'
        '${until.day.toString().padLeft(2, '0')}';
    await p.setString('$_kHiddenUntilPrefix${type.name}', key);
  }

  Future<void> clearHide(CoachNudgeType type) async {
    final p = await _prefsFuture;
    await p.remove('$_kHiddenUntilPrefix${type.name}');
  }

  Future<String> lastShownDateKey(CoachNudgeType type) async {
    final p = await _prefsFuture;
    return p.getString('$_kLastShownDatePrefix${type.name}') ?? '';
  }

  Future<void> markShownToday(CoachNudgeType type) async {
    final p = await _prefsFuture;
    await p.setString('$_kLastShownDatePrefix${type.name}', todayDateKey());
  }

  Future<bool> canShowToday(CoachNudgeType type) async {
    final today = todayDateKey();
    final last = await lastShownDateKey(type);
    if (last == today) return false;
    final hiddenUntil = await hiddenUntilDateKey(type);
    if (hiddenUntil.isEmpty) return true;
    // If hiddenUntil is today or later, do not show.
    return hiddenUntil.compareTo(today) < 0;
  }
}

