import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/planning_repository.dart';
import '../domain/task_block.dart';
import '../domain/task_unit.dart';

class LocalPlanningRepository implements PlanningRepository {
  LocalPlanningRepository({
    SharedPreferences? prefs,
  }) : _prefsFuture = prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;
  final _uuid = const Uuid();

  static const _kBlocks = 'planning.blocks.v1';
  static const _kSelectedByDate = 'planning.selectedByDate.v1';

  Future<List<TaskBlock>> _loadAll() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_kBlocks);
    if (raw == null || raw.trim().isEmpty) {
      final seeded = _seedDemo();
      await _saveAll(seeded);
      return seeded;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((m) => TaskBlock.fromJson(m.cast<String, Object?>()))
        .toList();
  }

  Future<void> _saveAll(List<TaskBlock> blocks) async {
    final prefs = await _prefsFuture;
    final raw = jsonEncode(blocks.map((b) => b.toJson()).toList());
    await prefs.setString(_kBlocks, raw);
  }

  Future<Map<String, Set<String>>> _loadSelectedByDate() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_kSelectedByDate);
    if (raw == null || raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((key, value) {
      final list = (value is List) ? value.whereType<String>().toList() : <String>[];
      return MapEntry(key.toString(), list.toSet());
    });
  }

  Future<void> _saveSelectedByDate(Map<String, Set<String>> map) async {
    final prefs = await _prefsFuture;
    final serializable = map.map((k, v) => MapEntry(k, v.toList()));
    await prefs.setString(_kSelectedByDate, jsonEncode(serializable));
  }

  List<TaskBlock> _seedDemo() {
    final id = _uuid.v4();
    return [
      TaskBlock(
        id: id,
        title: '과제 제출',
        units: [
          TaskUnit(id: _uuid.v4(), title: '자료 찾기'),
          TaskUnit(id: _uuid.v4(), title: '목차 작성'),
          TaskUnit(id: _uuid.v4(), title: '첫 문단 쓰기'),
          TaskUnit(id: _uuid.v4(), title: '제출하기'),
        ],
        isSelectedForToday: true,
      ),
      TaskBlock(
        id: _uuid.v4(),
        title: '방 정리',
        units: [
          TaskUnit(id: _uuid.v4(), title: '책상 위 5개만 치우기'),
          TaskUnit(id: _uuid.v4(), title: '바닥 쓰레기만 버리기'),
          TaskUnit(id: _uuid.v4(), title: '환기 2분'),
        ],
      ),
    ];
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<List<TaskBlock>> loadTodayVisibleBlocks(String dateKey) async {
    final all = await _loadAll();
    final selectedByDate = await _loadSelectedByDate();
    final sel = selectedByDate[dateKey] ?? {};
    return all.where((b) => sel.contains(b.id) || b.isSelectedForToday || b.isFullyComplete).toList();
  }

  @override
  Future<List<TaskBlock>> loadBacklog() async {
    final today = _todayKey();
    final selectedByDate = await _loadSelectedByDate();
    final sel = selectedByDate[today] ?? {};
    final all = await _loadAll();
    return all.where((b) => !b.isSelectedForToday && !sel.contains(b.id) && !b.isFullyComplete).toList();
  }

  @override
  Future<void> setSelectedForToday(String dateKey, List<String> blockIds) async {
    final selectedByDate = await _loadSelectedByDate();
    final selectedSet = blockIds.toSet();
    selectedByDate[dateKey] = selectedSet;
    await _saveSelectedByDate(selectedByDate);

    final all = await _loadAll();
    String? currentId;
    for (final b in all) {
      if (selectedSet.contains(b.id) && b.isCurrentTask && !b.isFullyComplete) {
        currentId = b.id;
        break;
      }
    }
    if (currentId == null && selectedSet.isNotEmpty) {
      for (final id in blockIds) {
        for (final b in all) {
          if (b.id == id && !b.isFullyComplete) {
            currentId = id;
            break;
          }
        }
        if (currentId != null) break;
      }
      currentId ??= blockIds.firstWhere((id) => selectedSet.contains(id), orElse: () => selectedSet.first);
    }
    final updated = [
      for (final b in all)
        b.copyWith(
          isSelectedForToday: selectedSet.contains(b.id),
          isCurrentTask: currentId != null && b.id == currentId,
        ),
    ];
    await _saveAll(updated);
  }

  @override
  Future<void> addBlock(TaskBlock block) async {
    final all = await _loadAll();
    await _saveAll([...all, block]);
  }

  @override
  Future<void> updateBlock(TaskBlock block) async {
    final all = await _loadAll();
    final i = all.indexWhere((b) => b.id == block.id);
    if (i < 0) return;
    all[i] = block;
    await _saveAll(all);
  }

  @override
  Future<void> deleteBlock(String blockId) async {
    final all = await _loadAll();
    all.removeWhere((b) => b.id == blockId);
    await _saveAll(all);

    final selectedByDate = await _loadSelectedByDate();
    for (final key in selectedByDate.keys.toList()) {
      final set = selectedByDate[key];
      if (set == null) continue;
      set.remove(blockId);
      if (set.isEmpty) {
        selectedByDate.remove(key);
      }
    }
    await _saveSelectedByDate(selectedByDate);
  }

  @override
  Future<void> setCurrentTask(String? blockId) async {
    final all = await _loadAll();
    final selected = all.where((b) => b.isSelectedForToday).toList();
    String? currentId = blockId;
    if (currentId == null && selected.isNotEmpty) {
      for (final b in selected) {
        if (!b.isFullyComplete) {
          currentId = b.id;
          break;
        }
      }
      currentId ??= selected.first.id;
    }
    final updated = [
      for (final b in all)
        b.copyWith(
          isCurrentTask: currentId != null && b.id == currentId,
        ),
    ];
    await _saveAll(updated);
  }

  @override
  Future<bool> canAddNewBlock(String dateKey) async {
    final visible = await loadTodayVisibleBlocks(dateKey);
    if (visible.isEmpty) return true;
    return visible.every((b) => b.isFullyComplete);
  }
}

