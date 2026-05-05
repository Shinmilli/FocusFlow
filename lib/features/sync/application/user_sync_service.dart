import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/api_config.dart';
import '../../../core/persistence/user_local_data_scope.dart';
import '../../gamification/domain/player_progress.dart';
import '../data/user_sync_api_client.dart';
import 'user_sync_pref_keys.dart';

bool syncPayloadLooksRich(Map<String, dynamic> p) {
  final b = p['planningBlocks'];
  if (b is List && b.isNotEmpty) return true;
  final e = p['focusEvents'];
  if (e is List && e.isNotEmpty) return true;
  final pr = p['playerProgress'];
  if (pr is Map) {
    final xp = (pr['xp'] as num?)?.toInt() ?? 0;
    final lvl = (pr['level'] as num?)?.toInt() ?? 1;
    final tb = (pr['totalBlocksCompleted'] as num?)?.toInt() ?? 0;
    if (xp > 0 || lvl > 1 || tb > 0) return true;
  }
  final g = p['goals'];
  if (g is List && g.isNotEmpty) return true;
  return false;
}

class UserSyncService {
  UserSyncService(this._ref, this._api);

  final Ref _ref;
  final UserSyncApiClient _api;

  /// 서버 → 로컬 SharedPreferences 반영 (무효화는 호출 측에서).
  Future<void> pullFromServerApplyPrefs() async {
    if (!kApiBaseUrlConfigured) return;
    final scope = _ref.read(userLocalDataStorageSuffixProvider);
    if (scope == null || scope == 'guest') return;

    Map<String, dynamic> remote = {};
    try {
      remote = await _api.fetchPayload();
    } catch (_) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final localSnapshot = await collectPayloadForScope(scope, prefs);
    final hasRemote = syncPayloadLooksRich(remote);
    final hasLocal = syncPayloadLooksRich(localSnapshot);

    if (hasRemote) {
      await applyPayloadToPrefs(scope, prefs, remote);
    } else if (hasLocal) {
      try {
        await _api.putPayload(localSnapshot);
      } catch (_) {}
    }
  }

  Future<void> pushFromLocal() async {
    if (!kApiBaseUrlConfigured) return;
    final scope = _ref.read(userLocalDataStorageSuffixProvider);
    if (scope == null || scope == 'guest') return;

    final prefs = await SharedPreferences.getInstance();
    final payload = await collectPayloadForScope(scope, prefs);
    await _api.putPayload(payload);
  }

  static Future<Map<String, dynamic>> collectPayloadForScope(String scope, SharedPreferences prefs) async {
    final blocksRaw = prefs.getString(scopedPreferenceKey(UserSyncPrefKeys.planningBlocks, scope)) ?? '[]';
    final selRaw = prefs.getString(scopedPreferenceKey(UserSyncPrefKeys.planningSelectedByDate, scope)) ?? '{}';
    final progRaw = prefs.getString(scopedPreferenceKey(UserSyncPrefKeys.playerProgress, scope));
    final goalsRaw = prefs.getString(scopedPreferenceKey(UserSyncPrefKeys.goalsList, scope)) ?? '[]';
    final eventsRaw = prefs.getString(scopedPreferenceKey(UserSyncPrefKeys.focusEvents, scope)) ?? '[]';

    List<dynamic> blocksDecoded = [];
    try {
      final d = jsonDecode(blocksRaw);
      if (d is List) blocksDecoded = d;
    } catch (_) {}

    Map<String, dynamic> selDecoded = {};
    try {
      final d = jsonDecode(selRaw);
      if (d is Map) {
        for (final e in d.entries) {
          final v = e.value;
          if (v is List) {
            selDecoded[e.key.toString()] = v;
          }
        }
      }
    } catch (_) {}

    Map<String, dynamic> progObj = {};
    if (progRaw != null && progRaw.isNotEmpty) {
      try {
        final d = jsonDecode(progRaw);
        if (d is Map) progObj = d.cast<String, dynamic>();
      } catch (_) {}
    }

    List<dynamic> goalsDecoded = [];
    try {
      final d = jsonDecode(goalsRaw);
      if (d is List) goalsDecoded = d;
    } catch (_) {}

    List<dynamic> eventsDecoded = [];
    try {
      final d = jsonDecode(eventsRaw);
      if (d is List) eventsDecoded = d;
    } catch (_) {}

    final weeklyTarget = prefs.getInt(scopedPreferenceKey(UserSyncPrefKeys.flowWeeklyTarget, scope)) ?? 5;

    return {
      'planningBlocks': blocksDecoded,
      'planningSelectedByDate': selDecoded,
      'playerProgress': progObj.isEmpty ? const PlayerProgress().toJson() : progObj,
      'goals': goalsDecoded,
      'focusEvents': eventsDecoded,
      'flowWeeklyTarget': weeklyTarget.clamp(1, 7),
    };
  }

  static Future<void> applyPayloadToPrefs(String scope, SharedPreferences prefs, Map<String, dynamic> remote) async {
    void writeJson(String baseKey, Object encodable) {
      prefs.setString(scopedPreferenceKey(baseKey, scope), jsonEncode(encodable));
    }

    if (remote['planningBlocks'] is List) {
      writeJson(UserSyncPrefKeys.planningBlocks, remote['planningBlocks']);
    }
    if (remote['planningSelectedByDate'] is Map) {
      writeJson(UserSyncPrefKeys.planningSelectedByDate, remote['planningSelectedByDate']);
    }
    if (remote['playerProgress'] is Map) {
      writeJson(UserSyncPrefKeys.playerProgress, remote['playerProgress']);
    }
    if (remote['goals'] is List) {
      writeJson(UserSyncPrefKeys.goalsList, remote['goals']);
    }
    if (remote['focusEvents'] is List) {
      writeJson(UserSyncPrefKeys.focusEvents, remote['focusEvents']);
    }
    if (remote['flowWeeklyTarget'] != null) {
      final v = (remote['flowWeeklyTarget'] as num?)?.toInt() ?? 5;
      await prefs.setInt(scopedPreferenceKey(UserSyncPrefKeys.flowWeeklyTarget, scope), v.clamp(1, 7));
    }
  }
}
