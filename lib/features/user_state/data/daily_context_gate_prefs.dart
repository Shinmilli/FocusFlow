import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/user_local_data_scope.dart';
import '../../../core/time/today_date_key.dart';

class DailyContextGatePrefs {
  DailyContextGatePrefs({
    required this.storageScope,
    SharedPreferences? prefs,
  }) : _prefsFuture = prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  final String? storageScope;

  final Future<SharedPreferences> _prefsFuture;

  static const _kLastSavedDateBase = 'userContext.lastSavedDate.v1';

  String? get _kLastSavedDate =>
      storageScope == null ? null : scopedPreferenceKey(_kLastSavedDateBase, storageScope);

  Future<bool> isDoneForToday() async {
    final key = _kLastSavedDate;
    if (key == null) return false;
    final p = await _prefsFuture;
    final last = p.getString(key) ?? '';
    return last == todayDateKey();
  }

  Future<void> markDoneForToday() async {
    final key = _kLastSavedDate;
    if (key == null) return;
    final p = await _prefsFuture;
    await p.setString(key, todayDateKey());
  }
}

