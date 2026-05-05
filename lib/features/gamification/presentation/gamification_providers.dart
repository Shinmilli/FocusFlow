import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/user_local_data_scope.dart';
import '../../sync/presentation/sync_providers.dart';
import '../domain/player_progress.dart';
import 'celebration_coordinator.dart';

final playerProgressProvider =
    StateNotifierProvider<PlayerProgressNotifier, PlayerProgress>((ref) {
  final scope = ref.watch(userLocalDataStorageSuffixProvider);
  final sched = ref.watch(userSyncSchedulerProvider);
  return PlayerProgressNotifier(ref, scope, onPersist: sched.schedulePush);
});

class PlayerProgressNotifier extends StateNotifier<PlayerProgress> {
  PlayerProgressNotifier(this._ref, this._storageScope, {this.onPersist}) : super(const PlayerProgress()) {
    if (_storageScope != null) _load();
  }

  final Ref _ref;
  final String? _storageScope;
  final VoidCallback? onPersist;

  static const _kProgressBase = 'player.progress.v1';
  static const _kRewardedBlocksBase = 'player.progress.rewardedBlocks.v2';

  String? get _kProgress => _storageScope == null
      ? null
      : scopedPreferenceKey(_kProgressBase, _storageScope);

  String? get _kRewardedBlocks => _storageScope == null
      ? null
      : scopedPreferenceKey(_kRewardedBlocksBase, _storageScope);

  /// dateKey(yyyy-MM-dd) -> rewarded block ids for that day.
  final Map<String, Set<String>> _rewardedBlockIdsByDay = <String, Set<String>>{};

  Future<void> _load() async {
    final key = _kProgress;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = PlayerProgress.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
      state = decoded;
    } catch (_) {
      // ignore corrupted state
    }

    // Load rewarded block ids by day (idempotent per day for block completion).
    final rewardKey = _kRewardedBlocks;
    if (rewardKey == null) return;
    final rewardRaw = prefs.getString(rewardKey);
    if (rewardRaw == null || rewardRaw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(rewardRaw);
      _rewardedBlockIdsByDay.clear();
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final k = entry.key?.toString() ?? '';
          final v = entry.value;
          if (k.isEmpty || v is! List) continue;
          _rewardedBlockIdsByDay[k] = v.whereType<String>().where((s) => s.trim().isNotEmpty).toSet();
        }
      } else if (decoded is List) {
        // Migration: v1 stored a flat list (once ever). Treat as "rewarded today" so toggling still idempotent.
        final today = _todayKey();
        _rewardedBlockIdsByDay[today] = decoded.whereType<String>().where((s) => s.trim().isNotEmpty).toSet();
      }
    } catch (_) {
      // ignore corrupted state
    }
  }

  Future<void> _save() async {
    final key = _kProgress;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(state.toJson()));
    final rewardKey = _kRewardedBlocks;
    if (rewardKey != null) {
      final enc = <String, List<String>>{
        for (final e in _rewardedBlockIdsByDay.entries) e.key: e.value.toList(),
      };
      await prefs.setString(rewardKey, jsonEncode(enc));
    }
    onPersist?.call();
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseKey(String key) {
    if (key.isEmpty) return null;
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  void grantBlockComplete({required String blockId}) {
    final id = blockId.trim();
    if (id.isEmpty) return;

    // If this block has already granted XP today, do nothing (even if user toggles done off/on).
    final today = _todayKey();
    final rewardedToday = _rewardedBlockIdsByDay[today] ?? <String>{};
    if (rewardedToday.contains(id)) return;

    final prev = state;
    final prevLevel = state.level;
    final prevStreak = state.streakDays;
    var next = state.addXp(25);

    // 연속: 하루에 블록 완료가 1번이라도 있으면 그날을 연속 기록에 포함.
    if (next.lastStreakDateKey != today) {
      final last = _parseKey(next.lastStreakDateKey);
      final now = _parseKey(today);
      var streak = next.streakDays;
      if (last == null || now == null) {
        streak = 1;
      } else {
        final lastDate = DateTime(last.year, last.month, last.day);
        final nowDate = DateTime(now.year, now.month, now.day);
        final diff = nowDate.difference(lastDate).inDays;
        if (diff == 1) {
          streak = streak + 1;
        } else if (diff > 1) {
          streak = 1;
        } else if (diff == 0) {
          // same day: no change
        } else {
          streak = 1;
        }
      }
      next = next.withStreakMeta(days: streak, lastDateKey: today);
    }

    next = next.withTotalBlocksIncremented();
    if (next.totalBlocksCompleted == 1) {
      next = next.unlockBadge('첫 블록 완료');
    }
    if (next.streakDays >= 3 && prevStreak < 3) {
      next = next.unlockBadge('3일 연속');
    }
    if (next.streakDays >= 7 && prevStreak < 7) {
      next = next.unlockBadge('7일 연속');
    }
    if (next.level >= 5 && prevLevel < 5) {
      next = next.unlockBadge('레벨 5');
    }

    // Record reward for today only.
    _rewardedBlockIdsByDay[today] = {...rewardedToday, id};
    state = next;
    _save();
    _ref.read(celebrationCoordinatorProvider).onProgressGained(prev, next);
  }
}
