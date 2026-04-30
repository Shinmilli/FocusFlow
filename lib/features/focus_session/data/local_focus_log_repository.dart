import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/user_local_data_scope.dart';
import '../domain/focus_log_event.dart';

class LocalFocusLogRepository {
  LocalFocusLogRepository({
    required this.storageScope,
    SharedPreferences? prefs,
  }) : _prefsFuture = prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  /// null이면 메모리만 (비로그인 + API 사용 중).
  final String? storageScope;

  final Future<SharedPreferences> _prefsFuture;

  static const _kEventsBase = 'focus.log.events.v1';
  static const _maxEvents = 400;

  final List<FocusLogEvent> _ephemeral = [];

  String? get _kEvents =>
      storageScope == null ? null : scopedPreferenceKey(_kEventsBase, storageScope);

  Future<List<FocusLogEvent>> loadAll() async {
    final key = _kEvents;
    if (key == null) {
      return List.unmodifiable(_ephemeral);
    }
    final prefs = await _prefsFuture;
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((m) => FocusLogEvent.fromJson(m.cast<String, Object?>()))
        .toList();
  }

  Future<void> append(FocusLogEvent event) async {
    final key = _kEvents;
    if (key == null) {
      _ephemeral.add(event);
      while (_ephemeral.length > _maxEvents) {
        _ephemeral.removeAt(0);
      }
      return;
    }
    final prefs = await _prefsFuture;
    final all = await loadAll();
    final next = [...all, event];
    final trimmed = next.length <= _maxEvents ? next : next.sublist(next.length - _maxEvents);
    await prefs.setString(key, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  Future<void> clear() async {
    final key = _kEvents;
    if (key == null) {
      _ephemeral.clear();
      return;
    }
    final prefs = await _prefsFuture;
    await prefs.remove(key);
  }
}

