import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/persistence/user_local_data_scope.dart';
import '../../../core/time/planning_date_key.dart';
import '../domain/planning_repository.dart';
import '../domain/task_block.dart';
import '../domain/task_unit.dart';

class LocalPlanningRepository implements PlanningRepository {
  LocalPlanningRepository({
    required this.storageScope,
    SharedPreferences? prefs,
    this.onMutate,
  }) : _prefsFuture = prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  /// `guest`일 때만 레거시 키(접미사 없음); 그 외 계정별 키.
  final String storageScope;

  /// 블록·선택 상태가 바뀐 뒤 (서버 동기화 등).
  final VoidCallback? onMutate;

  final Future<SharedPreferences> _prefsFuture;

  void _fireMutate() => onMutate?.call();
  final _uuid = const Uuid();

  static const _kBlocksBase = 'planning.blocks.v1';
  static const _kSelectedByDateBase = 'planning.selectedByDate.v1';
  static const _kArchivedDayBlocksBase = 'planning.archivedDayBlocks.v1';
  static const _kLastArchivedDayBase = 'planning.lastArchivedDay.v1';
  static const _kLastTodayKeyBase = 'planning.lastTodayKey.v1';
  static const _kLegacyTodaySelectionMigratedBase = 'planning.legacyTodaySelectionMigrated.v1';

  String get _kBlocks => scopedPreferenceKey(_kBlocksBase, storageScope);
  String get _kSelectedByDate => scopedPreferenceKey(_kSelectedByDateBase, storageScope);
  String get _kArchivedDayBlocks => scopedPreferenceKey(_kArchivedDayBlocksBase, storageScope);
  String get _kLastArchivedDay => scopedPreferenceKey(_kLastArchivedDayBase, storageScope);
  String get _kLastTodayKey => scopedPreferenceKey(_kLastTodayKeyBase, storageScope);
  String get _kLegacyTodaySelectionMigrated => scopedPreferenceKey(_kLegacyTodaySelectionMigratedBase, storageScope);

  TaskBlock _freezeForArchive(TaskBlock b) {
    return TaskBlock.fromJson(b.toJson()).copyWith(isCurrentTask: false);
  }

  Future<Map<String, Map<String, TaskBlock>>> _loadArchivedDayBlocks() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_kArchivedDayBlocks);
    if (raw == null || raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    final out = <String, Map<String, TaskBlock>>{};
    for (final e in decoded.entries) {
      final inner = e.value;
      if (inner is! Map) continue;
      final m = <String, TaskBlock>{};
      for (final ie in inner.entries) {
        final v = ie.value;
        if (v is! Map) continue;
        m[ie.key.toString()] = TaskBlock.fromJson(v.cast<String, Object?>());
      }
      out[e.key.toString()] = m;
    }
    return out;
  }

  Future<void> _saveArchivedDayBlocks(Map<String, Map<String, TaskBlock>> archived) async {
    final prefs = await _prefsFuture;
    final top = <String, dynamic>{};
    for (final e in archived.entries) {
      top[e.key] = e.value.map((id, b) => MapEntry(id, b.toJson()));
    }
    await prefs.setString(_kArchivedDayBlocks, jsonEncode(top));
  }

  Future<void> _purgeArchivedForBlock(String blockId) async {
    final archived = await _loadArchivedDayBlocks();
    var touched = false;
    for (final dayKey in archived.keys.toList()) {
      final m = archived[dayKey];
      if (m == null) continue;
      if (m.remove(blockId) != null) {
        touched = true;
        if (m.isEmpty) archived.remove(dayKey);
      }
    }
    if (touched) await _saveArchivedDayBlocks(archived);
  }

  /// 어제까지 지난 날짜 계획에 대해, 당시 선택된 블록 상태를 스냅샷으로 고정한다.
  Future<void> _ensureArchivedThroughYesterday(
    List<TaskBlock> all,
    Map<String, Set<String>> selectedByDate,
  ) async {
    final today = _todayKey();
    final yesterday = addCalendarDaysToPlanningDateKey(today, -1);

    final prefs = await _prefsFuture;
    final lastTodayKey = prefs.getString(_kLastTodayKey)?.trim();
    if (lastTodayKey == null || lastTodayKey.isEmpty) {
      await prefs.setString(_kLastTodayKey, today);
    } else if (lastTodayKey != today) {
      // 날짜가 바뀌었으면, 전날의 "오늘 선택/현재 작업" 플래그는 더 이상 유효하지 않다.
      // 오늘 선택은 selectedByDate[today]로만 결정되므로, 레거시 플래그를 모두 내린다.
      final updated = [
        for (final b in all) b.copyWith(isSelectedForToday: false, isCurrentTask: false),
      ];
      await _saveAll(updated);
      all
        ..clear()
        ..addAll(updated);
      await prefs.setString(_kLastTodayKey, today);
    }

    final lastRaw = prefs.getString(_kLastArchivedDay)?.trim();

    final endKey = yesterday;

    late String startKey;
    if (lastRaw == null || lastRaw.isEmpty) {
      final earliest = earliestPastPlanDayKey(selectedByDate.keys, today);
      startKey = earliest ?? yesterday;
    } else {
      startKey = addCalendarDaysToPlanningDateKey(lastRaw, 1);
    }

    if (comparePlanningDateKeys(startKey, endKey) > 0) return;

    var archived = await _loadArchivedDayBlocks();
    var dk = startKey;
    while (comparePlanningDateKeys(dk, endKey) <= 0) {
      final sel = selectedByDate[dk] ?? {};
      if (sel.isNotEmpty) {
        final dayMap = Map<String, TaskBlock>.from(archived[dk] ?? {});
        for (final id in sel) {
          TaskBlock? live;
          for (final b in all) {
            if (b.id == id) {
              live = b;
              break;
            }
          }
          if (live != null) {
            dayMap[id] = _freezeForArchive(live);
          }
        }
        archived[dk] = dayMap;
      }
      dk = addCalendarDaysToPlanningDateKey(dk, 1);
    }

    await _saveArchivedDayBlocks(archived);
    await prefs.setString(_kLastArchivedDay, yesterday);
  }

  TaskBlock? _resolveBlockForDate(
    String dateKey,
    String blockId,
    List<TaskBlock> all,
    Map<String, Map<String, TaskBlock>> archived,
  ) {
    final today = _todayKey();
    if (!isStrictlyPastPlanningDateKey(dateKey, today)) {
      for (final b in all) {
        if (b.id == blockId) return b;
      }
      return null;
    }
    final snap = archived[dateKey]?[blockId];
    if (snap != null) return snap;
    for (final b in all) {
      if (b.id == blockId) return b;
    }
    return null;
  }

  /// 레거시(`isSelectedForToday`) → 날짜별 선택(`selectedByDate[today]`) 1회 마이그레이션.
  ///
  /// 예전 버전에선 "오늘 선택"이 블록 필드에만 저장돼서 날짜가 지나도 유지될 수 있음.
  /// 새 규칙에선 날짜가 바뀌면 "오늘"은 비어 있고, 전날 선택은 백로그로 내려가야 하므로
  /// 최초 1회만 오늘 날짜 키에 선택을 기록해 준다.
  Future<Map<String, Set<String>>> _ensureTodaySelectionMigrated(
    List<TaskBlock> all,
    Map<String, Set<String>> selectedByDate,
  ) async {
    final prefs = await _prefsFuture;
    final already = prefs.getBool(_kLegacyTodaySelectionMigrated) ?? false;
    if (already) return selectedByDate;

    final today = _todayKey();
    final sel = selectedByDate[today];
    if (sel != null && sel.isNotEmpty) return selectedByDate;

    final legacySelected = all.where((b) => b.isSelectedForToday).map((b) => b.id).toSet();
    if (legacySelected.isEmpty) return selectedByDate;

    final next = {...selectedByDate, today: legacySelected};
    await _saveSelectedByDate(next);
    await prefs.setBool(_kLegacyTodaySelectionMigrated, true);
    return next;
  }

  Future<List<TaskBlock>> _loadAll() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_kBlocks);
    if (raw == null || raw.trim().isEmpty) {
      if (storageScope == 'guest') {
        final seeded = _seedDemo();
        await _saveAll(seeded);
        return seeded;
      }
      return [];
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
    var selectedByDate = await _loadSelectedByDate();
    selectedByDate = await _ensureTodaySelectionMigrated(all, selectedByDate);
    await _ensureArchivedThroughYesterday(all, selectedByDate);
    final archived = await _loadArchivedDayBlocks();
    final sel = selectedByDate[dateKey] ?? const <String>{};
    final out = <TaskBlock>[];
    for (final id in sel) {
      final b = _resolveBlockForDate(dateKey, id, all, archived);
      if (b != null) out.add(b);
    }
    return out;
  }

  @override
  Future<List<TaskBlock>> loadBacklog() async {
    final today = _todayKey();
    final all = await _loadAll();
    var selectedByDate = await _loadSelectedByDate();
    selectedByDate = await _ensureTodaySelectionMigrated(all, selectedByDate);
    final sel = selectedByDate[today] ?? const <String>{};
    return all
        .where((b) {
          final inPlan = sel.contains(b.id);
          return !inPlan && !b.isFullyComplete;
        })
        .toList();
  }

  @override
  Future<List<TaskBlock>> loadBacklogForDate(String dateKey) async {
    final all = await _loadAll();
    final selectedByDate = await _loadSelectedByDate();
    final sel = selectedByDate[dateKey] ?? {};
    return all.where((b) => !sel.contains(b.id) && !b.isFullyComplete).toList();
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
    final today = _todayKey();
    final shouldWriteTodayFlags = dateKey == today;
    final updated = [
      for (final b in all)
        b.copyWith(
          isSelectedForToday: shouldWriteTodayFlags ? selectedSet.contains(b.id) : b.isSelectedForToday,
          isCurrentTask: currentId != null && b.id == currentId,
        ),
    ];
    await _saveAll(updated);
    _fireMutate();
  }

  @override
  Future<void> addBlock(TaskBlock block) async {
    final all = await _loadAll();
    await _saveAll([...all, block]);
    _fireMutate();
  }

  @override
  Future<void> updateBlock(TaskBlock block) async {
    final all = await _loadAll();
    final i = all.indexWhere((b) => b.id == block.id);
    if (i < 0) return;
    all[i] = block;
    await _saveAll(all);
    _fireMutate();
  }

  @override
  Future<void> upsertPlanBlockForDate(String dateKey, TaskBlock block) async {
    final today = _todayKey();
    if (!isStrictlyPastPlanningDateKey(dateKey, today)) {
      await updateBlock(block);
      return;
    }
    final all = await _loadAll();
    var selectedByDate = await _loadSelectedByDate();
    selectedByDate = await _ensureTodaySelectionMigrated(all, selectedByDate);
    await _ensureArchivedThroughYesterday(all, selectedByDate);

    final archived = await _loadArchivedDayBlocks();
    final dayMap = Map<String, TaskBlock>.from(archived[dateKey] ?? {});
    dayMap[block.id] = _freezeForArchive(block);
    archived[dateKey] = dayMap;
    await _saveArchivedDayBlocks(archived);
    _fireMutate();
  }

  @override
  Future<void> setPlanBlockFullyCompleteForDate(String dateKey, String blockId, bool fullyComplete) async {
    final all = await _loadAll();
    TaskBlock? live;
    for (final b in all) {
      if (b.id == blockId) {
        live = b;
        break;
      }
    }
    if (live == null) return;

    final today = _todayKey();
    if (!isStrictlyPastPlanningDateKey(dateKey, today)) {
      final nextUnits = [
        for (final u in live.units) u.copyWith(isDone: fullyComplete),
      ];
      await updateBlock(
        live.copyWith(
          units: nextUnits,
        ),
      );
      return;
    }

    var selectedByDate = await _loadSelectedByDate();
    selectedByDate = await _ensureTodaySelectionMigrated(all, selectedByDate);
    await _ensureArchivedThroughYesterday(all, selectedByDate);

    final archived = await _loadArchivedDayBlocks();
    final base = archived[dateKey]?[blockId] ?? _freezeForArchive(live);
    final nextUnits = [
      for (final u in base.units) u.copyWith(isDone: fullyComplete),
    ];
    final next = base.copyWith(units: nextUnits, isCurrentTask: false);

    final dayMap = Map<String, TaskBlock>.from(archived[dateKey] ?? {});
    dayMap[blockId] = next;
    archived[dateKey] = dayMap;
    await _saveArchivedDayBlocks(archived);
    _fireMutate();
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
    await _purgeArchivedForBlock(blockId);
    _fireMutate();
  }

  @override
  Future<void> setCurrentTask(String? blockId) async {
    final all = await _loadAll();
    final today = _todayKey();
    final selectedByDate = await _loadSelectedByDate();
    final selectedIds = selectedByDate[today] ?? const <String>{};
    final selected = all.where((b) => selectedIds.contains(b.id)).toList();
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
    _fireMutate();
  }

  @override
  Future<bool> canAddNewBlock(String dateKey) async {
    final visible = await loadTodayVisibleBlocks(dateKey);
    if (visible.isEmpty) return true;
    return visible.every((b) => b.isFullyComplete);
  }
}

