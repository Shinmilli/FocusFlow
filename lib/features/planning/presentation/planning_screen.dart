import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/focus_flow_limits.dart';
import '../../ai_agent/presentation/ai_providers.dart';
import '../../focus_session/domain/focus_log_event.dart';
import '../../focus_session/presentation/focus_log_providers.dart';
import '../../gamification/presentation/gamification_providers.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../domain/task_unit.dart';
import 'planning_providers.dart';
import 'widgets/task_block_card.dart';

class PlanningScreen extends ConsumerWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBlocks = ref.watch(todayBlocksProvider);
    final asyncCanAdd = ref.watch(canAddNewBlockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘 블록'),
        actions: [
          IconButton(
            tooltip: '오늘 3개 선택',
            onPressed: () => context.push('/plan/select'),
            icon: const Icon(Icons.checklist_rtl_outlined),
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: () {
              ref.invalidate(todayBlocksProvider);
              ref.invalidate(backlogBlocksProvider);
              ref.invalidate(canAddNewBlockProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: asyncBlocks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (blocks) {
          if (blocks.isEmpty) {
            return const Center(
              child: Text('오늘 선택된 블록이 없어요. 설정에서 최대 3개까지 고를 수 있어요.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: blocks.length,
            itemBuilder: (context, i) {
              final b = blocks[i];
              return TaskBlockCard(
                block: b,
                onToggleUnitDone: (unitId, done) async {
                  final repo = ref.read(planningRepositoryProvider);
                  final updatedUnits = b.units
                      .map(
                        (u) => u.id == unitId ? u.copyWith(isDone: done) : u,
                      )
                      .toList();
                  await repo.updateBlock(b.copyWith(units: updatedUnits));
                  ref.invalidate(todayBlocksProvider);
                  ref.invalidate(backlogBlocksProvider);
                  ref.invalidate(canAddNewBlockProvider);
                  if (updatedUnits.every((u) => u.isDone)) {
                    ref.read(playerProgressProvider.notifier).grantBlockComplete();
                    await ref.read(focusLogRepositoryProvider).append(
                          FocusLogEvent(
                            type: FocusLogEventType.blockCompleted,
                            tsMs: DateTime.now().millisecondsSinceEpoch,
                            dateKey: todayDateKey(),
                            meta: {'blockTitle': b.title},
                          ),
                        );
                  }
                },
                onDecompose: () async {
                  final agent = ref.read(aiAgentServiceProvider);
                  final ctx = ref.read(userLifeContextProvider);
                  final repo = ref.read(planningRepositoryProvider);
                  final uuid = const Uuid();

                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const AlertDialog(
                      title: Text('쪼개는 중...'),
                      content: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),
                    ),
                  );

                  try {
                    final units = await agent.decomposeTask(
                      taskTitle: b.title,
                      context: ctx,
                    );
                    final sourceUnits = units.isEmpty ? b.units : units;

                    await repo.updateBlock(
                      b.copyWith(
                        units: [
                          for (final u in sourceUnits)
                            TaskUnit(id: uuid.v4(), title: u.title, isDone: false),
                        ],
                      ),
                    );
                    ref.invalidate(todayBlocksProvider);
                    ref.invalidate(backlogBlocksProvider);
                    ref.invalidate(canAddNewBlockProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('더 잘게 쪼갰어요')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('쪼개기 실패: $e')),
                      );
                    }
                  } finally {
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: asyncCanAdd.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (canAdd) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                canAdd
                    ? '지금은 새로운 큰 일을 더할 수 있어요. (하루 최대 ${FocusFlowLimits.maxSelectableBlocksPerDay}개 블록)'
                    : '아직 끝나지 않은 블록이 있어요. 과부하를 막기 위해 다음 일은 완료 후에 추가해요.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}