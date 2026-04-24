import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/player_progress.dart';

final playerProgressProvider =
    StateNotifierProvider<PlayerProgressNotifier, PlayerProgress>((ref) {
  return PlayerProgressNotifier();
});

class PlayerProgressNotifier extends StateNotifier<PlayerProgress> {
  PlayerProgressNotifier() : super(const PlayerProgress()) {
    _load();
  }

  static const _kProgress = 'player.progress.v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProgress);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = PlayerProgress.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
      state = decoded;
    } catch (_) {
      // ignore corrupted state
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProgress, jsonEncode(state.toJson()));
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

  void grantBlockComplete() {
    final today = _todayKey();
    final prevLevel = state.level;
    final prevStreak = state.streakDays;
    var next = state.addXp(25);

    // 스트릭: 하루에 블록 완료가 1번이라도 있으면 그날을 스트릭에 포함.
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

    state = next;
    _save();
  }
}
