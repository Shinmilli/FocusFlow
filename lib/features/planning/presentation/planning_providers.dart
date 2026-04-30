import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/user_local_data_scope.dart';
import '../../../core/time/today_date_key.dart';
import '../data/in_memory_planning_repository.dart';
import '../data/local_planning_repository.dart';
import '../domain/planning_repository.dart';
import '../domain/task_block.dart';

export '../../../core/time/today_date_key.dart' show todayDateKey;

final planningRepositoryProvider = Provider<PlanningRepository>((ref) {
  final scope = ref.watch(userLocalDataStorageSuffixProvider);
  if (scope == null) {
    return InMemoryPlanningRepository(ephemeral: true);
  }
  return LocalPlanningRepository(storageScope: scope);
});

final todayBlocksProvider = FutureProvider<List<TaskBlock>>((ref) async {
  final repo = ref.watch(planningRepositoryProvider);
  return repo.loadTodayVisibleBlocks(todayDateKey());
});

final blocksForDateProvider = FutureProvider.family<List<TaskBlock>, String>((ref, dateKey) async {
  final repo = ref.watch(planningRepositoryProvider);
  return repo.loadTodayVisibleBlocks(dateKey);
});

final backlogBlocksProvider = FutureProvider<List<TaskBlock>>((ref) async {
  final repo = ref.watch(planningRepositoryProvider);
  return repo.loadBacklog();
});

final canAddNewBlockProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(planningRepositoryProvider);
  return repo.canAddNewBlock(todayDateKey());
});

final canAddNewBlockForDateProvider = FutureProvider.family<bool, String>((ref, dateKey) async {
  final repo = ref.watch(planningRepositoryProvider);
  return repo.canAddNewBlock(dateKey);
});
