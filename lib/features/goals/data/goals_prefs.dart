import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class GoalsPrefs {
  GoalsPrefs({SharedPreferences? prefs})
      : _prefsFuture = prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;

  static const _kGoals = 'goals.list.v1';

  Future<List<String>> load() async {
    final p = await _prefsFuture;
    final raw = p.getString(_kGoals);
    if (raw == null || raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  Future<void> save(List<String> goals) async {
    final p = await _prefsFuture;
    final cleaned = goals.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    await p.setString(_kGoals, jsonEncode(cleaned));
  }
}

