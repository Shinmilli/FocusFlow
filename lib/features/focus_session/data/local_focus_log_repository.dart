import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/focus_log_event.dart';

class LocalFocusLogRepository {
  LocalFocusLogRepository({SharedPreferences? prefs})
      : _prefsFuture = prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;

  static const _kEvents = 'focus.log.events.v1';
  static const _maxEvents = 400;

  Future<List<FocusLogEvent>> loadAll() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_kEvents);
    if (raw == null || raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((m) => FocusLogEvent.fromJson(m.cast<String, Object?>()))
        .toList();
  }

  Future<void> append(FocusLogEvent event) async {
    final prefs = await _prefsFuture;
    final all = await loadAll();
    final next = [...all, event];
    final trimmed = next.length <= _maxEvents ? next : next.sublist(next.length - _maxEvents);
    await prefs.setString(_kEvents, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  Future<void> clear() async {
    final prefs = await _prefsFuture;
    await prefs.remove(_kEvents);
  }
}

