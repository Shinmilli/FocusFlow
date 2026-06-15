import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../focus_session/domain/focus_log_event.dart';
import '../../focus_session/presentation/focus_log_providers.dart';
import '../../gamification/presentation/gamification_providers.dart';
import '../domain/task_block.dart';
import 'planning_providers.dart';

/// 홈·집중 모드 공통 — 현재 작업(`isCurrentTask`) 우선, 없으면 첫 미완료.
TaskBlock? resolveActiveTaskBlock(List<TaskBlock> blocks) {
  if (blocks.isEmpty) return null;
  for (final b in blocks) {
    if (b.isCurrentTask && !b.isFullyComplete) return b;
  }
  for (final b in blocks) {
    if (!b.isFullyComplete) return b;
  }
  return blocks.first;
}

/// 단계 완료 토글 — 홈·집중 모드에서 동일하게 저장·갱신.
Future<void> toggleTaskUnitDone({
  required WidgetRef ref,
  required TaskBlock block,
  required String unitId,
  required bool done,
}) async {
  final repo = ref.read(planningRepositoryProvider);
  final wasAllDone = block.units.every((u) => u.isDone);
  final updatedUnits = block.units
      .map((u) => u.id == unitId ? u.copyWith(isDone: done) : u)
      .toList();
  final nowAllDone = updatedUnits.every((u) => u.isDone);

  await repo.updateBlock(block.copyWith(units: updatedUnits));
  ref.invalidate(todayBlocksProvider);
  ref.invalidate(backlogBlocksProvider);
  ref.invalidate(canAddNewBlockProvider);

  if (!wasAllDone && nowAllDone) {
    ref.read(playerProgressProvider.notifier).grantBlockComplete(blockId: block.id);
    await ref.read(focusLogRepositoryProvider).append(
          FocusLogEvent(
            type: FocusLogEventType.blockCompleted,
            tsMs: DateTime.now().millisecondsSinceEpoch,
            dateKey: todayDateKey(),
            meta: {'blockTitle': block.title},
          ),
        );
  }
}
