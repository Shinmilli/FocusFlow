import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/user_local_data_scope.dart';

class GoalsPrefs {
  GoalsPrefs({
    required this.storageScope,
    SharedPreferences? prefs,
  }) : _prefsFuture = prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  final String? storageScope;

  final Future<SharedPreferences> _prefsFuture;

  static const _kGoalsBase = 'goals.list.v1';

  String? get _kGoals =>
      storageScope == null ? null : scopedPreferenceKey(_kGoalsBase, storageScope);

  Future<List<String>> load() async {
    final key = _kGoals;
    if (key == null) return [];
    final p = await _prefsFuture;
    final raw = p.getString(key);
    if (raw == null || raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  Future<void> save(List<String> goals) async {
    final key = _kGoals;
    if (key == null) return;
    final p = await _prefsFuture;
    final cleaned = goals.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    await p.setString(key, jsonEncode(cleaned));
  }
}

