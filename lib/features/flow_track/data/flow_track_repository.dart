import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/user_local_data_scope.dart';
import '../../focus_session/domain/focus_log_event.dart';
import '../domain/flow_week_segment.dart';
import '../domain/iso_week.dart';

class FlowTrackRepository {
  FlowTrackRepository({
    required this.storageScope,
    SharedPreferences? prefs,
  }) : _prefsFuture = prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  /// null이면 주간 목표·세그먼트 스냅샷만 메모리(비로그인 + API).
  final String? storageScope;

  final Future<SharedPreferences> _prefsFuture;

  static const _kSegmentsBase = 'flowtrack.segments.v1';
  static const _kWeeklyTargetBase = 'flowtrack.weeklyTarget.v1';

  int _weeklyTargetMem = 5;

  String? get _kSegments =>
      storageScope == null ? null : scopedPreferenceKey(_kSegmentsBase, storageScope);
  String? get _kWeeklyTarget =>
      storageScope == null ? null : scopedPreferenceKey(_kWeeklyTargetBase, storageScope);

  Future<int> weeklyTarget() async {
    final key = _kWeeklyTarget;
    if (key == null) return _weeklyTargetMem;
    final p = await _prefsFuture;
    return p.getInt(key) ?? 5;
  }

  Future<void> setWeeklyTarget(int v) async {
    final key = _kWeeklyTarget;
    final clamped = v.clamp(1, 7);
    if (key == null) {
      _weeklyTargetMem = clamped;
      return;
    }
    final p = await _prefsFuture;
    await p.setInt(key, clamped);
  }

  Future<void> _saveAll(List<FlowWeekSegment> segments) async {
    final key = _kSegments;
    if (key == null) return;
    final p = await _prefsFuture;
    final raw = jsonEncode(segments.map((s) => s.toJson()).toList());
    await p.setString(key, raw);
  }

  String _tierForStreak(int streakWeeks) {
    if (streakWeeks >= 40) return 'Mythic';
    if (streakWeeks >= 27) return 'Diamond';
    if (streakWeeks >= 19) return 'Ruby';
    if (streakWeeks >= 14) return 'Sapphire';
    if (streakWeeks >= 10) return 'Platinum';
    if (streakWeeks >= 7) return 'Gold';
    if (streakWeeks >= 4) return 'Silver';
    if (streakWeeks >= 2) return 'Bronze';
    return 'Iron';
  }

  Future<List<FlowWeekSegment>> buildSegmentsFromEvents(List<FocusLogEvent> events) async {
    final target = await weeklyTarget();
    // Count focusCompleted per week.
    final completedByWeek = <String, int>{};

    DateTime? minDay;
    DateTime? maxDay;

    for (final e in events) {
      if (e.type != FocusLogEventType.focusCompleted) continue;
      final d = parseDateKey(e.dateKey) ?? DateTime.fromMillisecondsSinceEpoch(e.tsMs);
      final day = DateTime(d.year, d.month, d.day);
      minDay = minDay == null || day.isBefore(minDay) ? day : minDay;
      maxDay = maxDay == null || day.isAfter(maxDay) ? day : maxDay;

      final wk = isoWeekKey(day);
      completedByWeek[wk] = (completedByWeek[wk] ?? 0) + 1;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    minDay ??= today;
    maxDay ??= today;

    final startMonday = startOfIsoWeek(minDay);
    final endMonday = startOfIsoWeek(maxDay);
    final weeks = isoWeekRangeInclusive(startMonday, endMonday);

    // Build from oldest to newest to compute streak/gauge.
    var streak = 0;
    var gauge = 0.0;
    var prevSuccess = false;

    final out = <FlowWeekSegment>[];
    for (final monday in weeks) {
      final wk = isoWeekKey(monday);
      final count = completedByWeek[wk] ?? 0;
      final success = count >= target;

      if (success) {
        streak = streak + 1;
      } else {
        streak = 0;
      }

      // masteryGauge: small gain on success, decay on failure; if near 1 then 20% penalty on failure.
      if (success) {
        gauge = (gauge + 0.08).clamp(0.0, 1.0);
      } else {
        if (gauge >= 0.8) {
          gauge = (gauge - 0.2).clamp(0.0, 1.0);
        } else {
          gauge = (gauge - 0.05).clamp(0.0, 1.0);
        }
      }

      final tier = _tierForStreak(streak);
      final repairMark = success && !prevSuccess && out.isNotEmpty;

      final merged = FlowWeekSegment(
        weekKey: wk,
        weekStartDateKey: dateKeyFromDate(monday),
        weeklyTarget: target,
        completedCount: count,
        success: success,
        streakWeeks: streak,
        masteryGauge: gauge,
        tier: tier,
        repairMark: repairMark,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );

      out.add(merged);
      prevSuccess = success;
    }

    // Persist newest snapshot for future UI.
    await _saveAll(out);

    return out;
  }
}

