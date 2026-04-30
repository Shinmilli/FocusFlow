import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/user_local_data_scope.dart';
import '../../../core/time/today_date_key.dart';

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
  CoachNudgePrefs({
    required this.storageScope,
    SharedPreferences? prefs,
  }) : _prefsFuture = prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  final String? storageScope;

  final Future<SharedPreferences> _prefsFuture;

  static const _kIntensityBase = 'coach.intensity.v1';
  static const _kHiddenUntilPrefix = 'coach.hiddenUntil.'; // + type
  static const _kLastShownDatePrefix = 'coach.lastShownDate.'; // + type

  String? _scoped(String logicalKey) =>
      storageScope == null ? null : scopedPreferenceKey(logicalKey, storageScope);

  Future<CoachNudgeIntensity> intensity() async {
    final key = _scoped(_kIntensityBase);
    if (key == null) return CoachNudgeIntensity.active;
    final p = await _prefsFuture;
    final raw = p.getString(key) ?? CoachNudgeIntensity.active.name;
    return CoachNudgeIntensity.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => CoachNudgeIntensity.active,
    );
  }

  Future<void> setIntensity(CoachNudgeIntensity v) async {
    final key = _scoped(_kIntensityBase);
    if (key == null) return;
    final p = await _prefsFuture;
    await p.setString(key, v.name);
  }

  Future<String> hiddenUntilDateKey(CoachNudgeType type) async {
    final key = _scoped('$_kHiddenUntilPrefix${type.name}');
    if (key == null) return '';
    final p = await _prefsFuture;
    return p.getString(key) ?? '';
  }

  Future<void> hideForDays(CoachNudgeType type, int days) async {
    final prefsKey = _scoped('$_kHiddenUntilPrefix${type.name}');
    if (prefsKey == null) return;
    final p = await _prefsFuture;
    final now = DateTime.now();
    final until = now.add(Duration(days: days));
    final untilDate = '${until.year.toString().padLeft(4, '0')}-'
        '${until.month.toString().padLeft(2, '0')}-'
        '${until.day.toString().padLeft(2, '0')}';
    await p.setString(prefsKey, untilDate);
  }

  Future<void> clearHide(CoachNudgeType type) async {
    final key = _scoped('$_kHiddenUntilPrefix${type.name}');
    if (key == null) return;
    final p = await _prefsFuture;
    await p.remove(key);
  }

  Future<String> lastShownDateKey(CoachNudgeType type) async {
    final key = _scoped('$_kLastShownDatePrefix${type.name}');
    if (key == null) return '';
    final p = await _prefsFuture;
    return p.getString(key) ?? '';
  }

  Future<void> markShownToday(CoachNudgeType type) async {
    final key = _scoped('$_kLastShownDatePrefix${type.name}');
    if (key == null) return;
    final p = await _prefsFuture;
    await p.setString(key, todayDateKey());
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

