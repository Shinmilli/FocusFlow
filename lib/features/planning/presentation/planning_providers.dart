import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_planning_repository.dart';
import '../domain/planning_repository.dart';
import '../domain/task_block.dart';

final planningRepositoryProvider = Provider<PlanningRepository>((ref) {
  return LocalPlanningRepository();
});

String todayDateKey() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

final todayBlocksProvider = FutureProvider<List<TaskBlock>>((ref) async {
  final repo = ref.watch(planningRepositoryProvider);
  return repo.loadTodayVisibleBlocks(todayDateKey());
});

final backlogBlocksProvider = FutureProvider<List<TaskBlock>>((ref) async {
  final repo = ref.watch(planningRepositoryProvider);
  return repo.loadBacklog();
});

final canAddNewBlockProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(planningRepositoryProvider);
  return repo.canAddNewBlock(todayDateKey());
});
