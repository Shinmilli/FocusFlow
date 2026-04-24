import 'package:shared_preferences/shared_preferences.dart';

import '../../planning/presentation/planning_providers.dart';

class DailyContextGatePrefs {
  DailyContextGatePrefs({SharedPreferences? prefs})
      : _prefsFuture = prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;

  static const _kLastSavedDate = 'userContext.lastSavedDate.v1';

  Future<bool> isDoneForToday() async {
    final p = await _prefsFuture;
    final last = p.getString(_kLastSavedDate) ?? '';
    return last == todayDateKey();
  }

  Future<void> markDoneForToday() async {
    final p = await _prefsFuture;
    await p.setString(_kLastSavedDate, todayDateKey());
  }
}

