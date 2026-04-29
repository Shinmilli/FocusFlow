import 'package:uuid/uuid.dart';

import '../domain/planning_repository.dart';
import '../domain/task_block.dart';
import '../domain/task_unit.dart';

class InMemoryPlanningRepository implements PlanningRepository {
  InMemoryPlanningRepository() {
    _seedDemo();
  }

  final _uuid = const Uuid();
  final List<TaskBlock> _all = [];
  final Map<String, Set<String>> _selectedByDate = {};

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

  @override
  Future<List<TaskBlock>> loadTodayVisibleBlocks(String dateKey) async {
    final sel = _selectedByDate[dateKey] ?? {};
    return _all.where((b) => sel.contains(b.id) || b.isSelectedForToday || b.isFullyComplete).toList();
  }

  @override
  Future<List<TaskBlock>> loadBacklog() async {
    final today = _todayKey();
    final sel = _selectedByDate[today] ?? {};
    return _all
        .where((b) => !b.isSelectedForToday && !sel.contains(b.id) && !b.isFullyComplete)
        .toList();
  }

  @override
  Future<void> setSelectedForToday(String dateKey, List<String> blockIds) async {
    final selectedSet = blockIds.toSet();
    _selectedByDate[dateKey] = selectedSet;
    for (var i = 0; i < _all.length; i++) {
      final b = _all[i];
      _all[i] = b.copyWith(
        isSelectedForToday: selectedSet.contains(b.id),
        isCurrentTask: selectedSet.contains(b.id) ? b.isCurrentTask : false,
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
  Future<void> deleteBlock(String blockId) async {
    _all.removeWhere((b) => b.id == blockId);
    for (final key in _selectedByDate.keys.toList()) {
      final set = _selectedByDate[key];
      if (set == null) continue;
      set.remove(blockId);
      if (set.isEmpty) _selectedByDate.remove(key);
    }
  }

  @override
  Future<void> setCurrentTask(String? blockId) async {
    for (var i = 0; i < _all.length; i++) {
      final b = _all[i];
      _all[i] = b.copyWith(
        isCurrentTask: blockId != null && b.id == blockId,
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
