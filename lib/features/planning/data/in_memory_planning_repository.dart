import 'package:uuid/uuid.dart';

import '../../../core/time/planning_date_key.dart';
import '../domain/planning_repository.dart';
import '../domain/task_block.dart';
import '../domain/task_unit.dart';

class InMemoryPlanningRepository implements PlanningRepository {
  InMemoryPlanningRepository({this.ephemeral = false}) {
    if (!ephemeral) _seedDemo();
  }

  /// true면 비로그인(API 켜짐)용 — 디스크 없이 빈 저장소.
  final bool ephemeral;

  final _uuid = const Uuid();
  final List<TaskBlock> _all = [];
  final Map<String, Set<String>> _selectedByDate = {};
  final Map<String, Map<String, TaskBlock>> _archivedByDay = {};
  String? _lastArchivedDay;
  String? _lastTodayKey;
  bool _legacyTodaySelectionMigrated = false;

  void _seedDemo() {
    final id = _uuid.v4();
    _all.add(
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
    );
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  TaskBlock _freezeForArchive(TaskBlock b) {
    return TaskBlock.fromJson(b.toJson()).copyWith(isCurrentTask: false);
  }

  TaskBlock? _findLive(String blockId) {
    for (final b in _all) {
      if (b.id == blockId) return b;
    }
    return null;
  }

  void _purgeArchivedForBlock(String blockId) {
    for (final dayKey in _archivedByDay.keys.toList()) {
      final m = _archivedByDay[dayKey];
      if (m == null) continue;
      m.remove(blockId);
      if (m.isEmpty) _archivedByDay.remove(dayKey);
    }
  }

  void _ensureTodaySelectionMigrated() {
    if (_legacyTodaySelectionMigrated) return;
    final today = _todayKey();
    final sel = _selectedByDate[today];
    if (sel != null && sel.isNotEmpty) return;
    final legacy = _all.where((b) => b.isSelectedForToday).map((b) => b.id).toSet();
    if (legacy.isEmpty) return;
    _selectedByDate[today] = legacy;
    _legacyTodaySelectionMigrated = true;
  }

  void _ensureArchivedThroughYesterday() {
    _ensureTodaySelectionMigrated();
    final today = _todayKey();
    final last = _lastTodayKey;
    if (last == null) {
      _lastTodayKey = today;
    } else if (last != today) {
      // 날짜가 바뀌면, 전날의 "오늘 선택/현재 작업" 플래그는 더 이상 유효하지 않다.
      for (var i = 0; i < _all.length; i++) {
        _all[i] = _all[i].copyWith(isSelectedForToday: false, isCurrentTask: false);
      }
      _lastTodayKey = today;
    }
    final yesterday = addCalendarDaysToPlanningDateKey(today, -1);

    final lastRaw = _lastArchivedDay?.trim();

    late String startKey;
    if (lastRaw == null || lastRaw.isEmpty) {
      final earliest = earliestPastPlanDayKey(_selectedByDate.keys, today);
      startKey = earliest ?? yesterday;
    } else {
      startKey = addCalendarDaysToPlanningDateKey(lastRaw, 1);
    }

    if (comparePlanningDateKeys(startKey, yesterday) > 0) return;

    var dk = startKey;
    while (comparePlanningDateKeys(dk, yesterday) <= 0) {
      final sel = _selectedByDate[dk] ?? {};
      if (sel.isNotEmpty) {
        final dayMap = Map<String, TaskBlock>.from(_archivedByDay[dk] ?? {});
        for (final id in sel) {
          final live = _findLive(id);
          if (live != null) {
            dayMap[id] = _freezeForArchive(live);
          }
        }
        _archivedByDay[dk] = dayMap;
      }
      dk = addCalendarDaysToPlanningDateKey(dk, 1);
    }

    _lastArchivedDay = yesterday;
  }

  TaskBlock? _resolveBlockForDate(String dateKey, String blockId) {
    final today = _todayKey();
    if (!isStrictlyPastPlanningDateKey(dateKey, today)) {
      return _findLive(blockId);
    }
    return _archivedByDay[dateKey]?[blockId] ?? _findLive(blockId);
  }

  @override
  Future<List<TaskBlock>> loadTodayVisibleBlocks(String dateKey) async {
    _ensureArchivedThroughYesterday();
    final sel = _selectedByDate[dateKey] ?? const <String>{};
    final out = <TaskBlock>[];
    for (final id in sel) {
      final b = _resolveBlockForDate(dateKey, id);
      if (b != null) out.add(b);
    }
    return out;
  }

  @override
  Future<List<TaskBlock>> loadBacklog() async {
    _ensureArchivedThroughYesterday();
    final today = _todayKey();
    final sel = _selectedByDate[today] ?? const <String>{};
    return _all.where((b) {
      final inPlan = sel.contains(b.id);
      return !inPlan && !b.isFullyComplete;
    }).toList();
  }

  @override
  Future<List<TaskBlock>> loadBacklogForDate(String dateKey) async {
    final sel = _selectedByDate[dateKey] ?? {};
    return _all.where((b) => !sel.contains(b.id) && !b.isFullyComplete).toList();
  }

  @override
  Future<void> setSelectedForToday(String dateKey, List<String> blockIds) async {
    final selectedSet = blockIds.toSet();
    _selectedByDate[dateKey] = selectedSet;
    String? currentId;
    for (final b in _all) {
      if (selectedSet.contains(b.id) && b.isCurrentTask && !b.isFullyComplete) {
        currentId = b.id;
        break;
      }
    }
    if (currentId == null && selectedSet.isNotEmpty) {
      for (final id in blockIds) {
        for (final b in _all) {
          if (b.id == id && !b.isFullyComplete) {
            currentId = id;
            break;
          }
        }
        if (currentId != null) break;
      }
      currentId ??= blockIds.isNotEmpty ? blockIds.first : selectedSet.first;
    }
    final today = _todayKey();
    final shouldWriteTodayFlags = dateKey == today;
    for (var i = 0; i < _all.length; i++) {
      final b = _all[i];
      _all[i] = b.copyWith(
        isSelectedForToday: shouldWriteTodayFlags ? selectedSet.contains(b.id) : b.isSelectedForToday,
        isCurrentTask: currentId != null && b.id == currentId,
      );
    }
  }

  @override
  Future<void> addBlock(TaskBlock block) async {
    _all.add(block);
  }

  @override
  Future<void> updateBlock(TaskBlock block) async {
    final i = _all.indexWhere((b) => b.id == block.id);
    if (i >= 0) _all[i] = block;
  }

  @override
  Future<void> upsertPlanBlockForDate(String dateKey, TaskBlock block) async {
    final today = _todayKey();
    if (!isStrictlyPastPlanningDateKey(dateKey, today)) {
      await updateBlock(block);
      return;
    }
    _ensureArchivedThroughYesterday();
    final dayMap = Map<String, TaskBlock>.from(_archivedByDay[dateKey] ?? {});
    dayMap[block.id] = _freezeForArchive(block);
    _archivedByDay[dateKey] = dayMap;
  }

  @override
  Future<void> setPlanBlockFullyCompleteForDate(String dateKey, String blockId, bool fullyComplete) async {
    final live = _findLive(blockId);
    if (live == null) return;

    final today = _todayKey();
    if (!isStrictlyPastPlanningDateKey(dateKey, today)) {
      final nextUnits = [
        for (final u in live.units) u.copyWith(isDone: fullyComplete),
      ];
      await updateBlock(live.copyWith(units: nextUnits));
      return;
    }

    _ensureArchivedThroughYesterday();
    final base = _archivedByDay[dateKey]?[blockId] ?? _freezeForArchive(live);
    final nextUnits = [
      for (final u in base.units) u.copyWith(isDone: fullyComplete),
    ];
    final next = base.copyWith(units: nextUnits, isCurrentTask: false);

    final dayMap = Map<String, TaskBlock>.from(_archivedByDay[dateKey] ?? {});
    dayMap[blockId] = next;
    _archivedByDay[dateKey] = dayMap;
  }

  @override
  Future<void> deleteBlock(String blockId) async {
    _all.removeWhere((b) => b.id == blockId);
    for (final key in _selectedByDate.keys.toList()) {
      final set = _selectedByDate[key];
      if (set == null) continue;
      set.remove(blockId);
      if (set.isEmpty) _selectedByDate.remove(key);
    }
    _purgeArchivedForBlock(blockId);
  }

  @override
  Future<void> setCurrentTask(String? blockId) async {
    _ensureArchivedThroughYesterday();
    final today = _todayKey();
    final selectedIds = _selectedByDate[today] ?? const <String>{};
    String? currentId = blockId;
    if (currentId == null) {
      for (final b in _all) {
        if (selectedIds.contains(b.id) && !b.isFullyComplete) {
          currentId = b.id;
          break;
        }
      }
      if (currentId == null) {
        for (final b in _all) {
          if (selectedIds.contains(b.id)) {
            currentId = b.id;
            break;
          }
        }
      }
    }
    for (var i = 0; i < _all.length; i++) {
      final b = _all[i];
      _all[i] = b.copyWith(
        isCurrentTask: currentId != null && b.id == currentId,
      );
    }
  }

  @override
  Future<bool> canAddNewBlock(String dateKey) async {
    final visible = await loadTodayVisibleBlocks(dateKey);
    if (visible.isEmpty) return true;
    return visible.every((b) => b.isFullyComplete);
  }
}
