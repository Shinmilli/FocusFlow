import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../ai_agent/presentation/ai_providers.dart';
import '../../focus_session/domain/focus_log_event.dart';
import '../../focus_session/presentation/focus_log_providers.dart';
import '../../gamification/presentation/gamification_providers.dart';
import '../../gamification/domain/player_progress.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../domain/task_block.dart';
import '../domain/task_unit.dart';
import '../../coach/presentation/coach_nudge_controller.dart';
import 'planning_providers.dart';
import 'widgets/task_block_card.dart';

class PlanningScreen extends ConsumerWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBlocks = ref.watch(todayBlocksProvider);
    final progress = ref.watch(playerProgressProvider);
    final ctx = ref.watch(userLifeContextProvider);
    final lowEnergy = ctx.sleepHours < 6 || ctx.stressLevel >= 4;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Show at most one coach nudge per entry.
      showCoachNudgeIfAny(context: context, ref: ref);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘 블록'),
        actions: [
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
          final viewportWidth = MediaQuery.of(context).size.width;
          final isMobile = viewportWidth < 760;
          final isLaptop = viewportWidth >= 760 && viewportWidth < 1200;
          final isLarge = viewportWidth >= 1200;
          final pagePadding = isMobile ? 16.0 : 12.0;
          final sectionGap = isMobile ? 12.0 : 8.0;
          final taskRailHeight = isMobile ? 252.0 : (isLaptop ? 300.0 : 320.0);
          final taskCardWidth = isMobile ? 220.0 : (isLaptop ? 240.0 : 260.0);
          final currentBlocks = blocks.where((b) => b.isCurrentTask).toList();
          final incompleteBlocks = blocks.where((b) => !b.isFullyComplete && !b.isCurrentTask).toList();
          final completeBlocks = blocks.where((b) => b.isFullyComplete && !b.isCurrentTask).toList();
          final orderedBlocks = [...currentBlocks, ...incompleteBlocks, ...completeBlocks];
          final xpToNext = PlayerProgress.xpForLevel(progress.level);
          final xpRatio = xpToNext <= 0 ? 0.0 : (progress.xp / xpToNext).clamp(0.0, 1.0);
          final top = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('레벨', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Lv. ${progress.level}', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(value: xpRatio),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${progress.xp} / $xpToNext', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '스트릭 ${progress.streakDays}일 · 누적 완료 ${progress.totalBlocksCompleted}블록',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: sectionGap),
              FilledButton.icon(
                onPressed: () => context.push('/focus'),
                icon: const Icon(Icons.timer_outlined),
                label: Text(lowEnergy ? '딱 5분만 시작' : '집중 시작'),
              ),
              SizedBox(height: sectionGap),
              Row(
                children: [
                  Text('오늘', style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 8),
            ],
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final contentMaxWidth = isMobile ? double.infinity : (isLaptop ? 980.0 : 1180.0);
              final railHeight = isLaptop ? 290.0 : taskRailHeight;
              final railCardWidth = isLarge ? 250.0 : (isLaptop ? 220.0 : taskCardWidth);
              final listChild = blocks.isEmpty
                  ? ListView(
                      padding: EdgeInsets.all(pagePadding),
                      children: [
                        top,
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('오늘 블록이 비어 있어요', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                const Text('오늘 할 블록을 선택해 시작해요.'),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () => context.push('/plan/select'),
                                  icon: const Icon(Icons.checklist_rtl_outlined),
                                  label: const Text('오늘 선택'),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => context.push('/plan/add'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('큰 일 추가하고 쪼개기'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final agent = ref.read(aiAgentServiceProvider);
                            final ctx = ref.read(userLifeContextProvider);
                            final repo = ref.read(planningRepositoryProvider);

                            showDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const AlertDialog(
                                title: Text('AI 제안 만드는 중...'),
                                content: Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: LinearProgressIndicator(),
                                ),
                              ),
                            );

                            try {
                              final backlog = await repo.loadBacklog();
                              final proposal = await agent.buildTodayPlan(
                                context: ctx,
                                userStatedTasks: backlog.map((b) => b.title).take(8).toList(),
                                currentBacklog: backlog,
                              );
                              if (!context.mounted) return;
                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(proposal.messageForUser)),
                              );
                            } catch (e) {
                              if (context.mounted) Navigator.pop(context);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('AI 제안 실패: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('AI로 오늘 계획 제안 보기'),
                        ),
                      ],
                    )
                  : ListView(
                      padding: EdgeInsets.all(pagePadding),
                      children: [
                        top,
                        SizedBox(
                          height: railHeight,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: orderedBlocks.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, i) {
                              final b = orderedBlocks[i];
                              return SizedBox(
                                width: railCardWidth,
                                child: TaskBlockCard(
                                  margin: EdgeInsets.zero,
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
                                      final currentTitles = b.units.map((u) => u.title.trim()).toList();
                                      final nextTitles = sourceUnits.map((u) => u.title.trim()).toList();
                                      final changed = currentTitles.length != nextTitles.length ||
                                          currentTitles.asMap().entries.any((e) => e.value != nextTitles[e.key]);

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
                                          SnackBar(
                                            content: Text(
                                              changed
                                                  ? '체크리스트를 더 잘게 업데이트했어요.'
                                                  : 'AI 분해 결과가 기존과 같아요. 제목을 더 구체적으로 적으면 더 달라져요.',
                                            ),
                                          ),
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
                                  onDelete: b.isFullyComplete
                                      ? null
                                      : () => _removeFromTodayOnly(context, ref, b, orderedBlocks),
                                  onEditChecklist:
                                      b.isFullyComplete ? null : () => _editTodayChecklist(context, ref, b),
                                  onSetCurrentTask:
                                      b.isFullyComplete ? null : () => _setAsCurrentTask(context, ref, b),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: listChild,
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Card(
            clipBehavior: Clip.none,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
              child: SizedBox(
                height: 72,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _BottomAction(
                        icon: Icons.date_range_outlined,
                        label: '주간',
                        onTap: () => context.push('/plan/week'),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Transform.translate(
                            offset: const Offset(0, -20),
                            child: Material(
                              elevation: 6,
                              shadowColor: Colors.black26,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              color: Theme.of(context).colorScheme.primary,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => context.push('/plan/select'),
                                child: const SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Icon(Icons.add, color: Colors.white, size: 28),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _BottomAction(
                        icon: Icons.person_outline,
                        label: '프로필',
                        onTap: () => context.push('/profile'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _removeFromTodayOnly(
    BuildContext context,
    WidgetRef ref,
    TaskBlock block,
    List<TaskBlock> visibleBlocks,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('오늘 할 일에서 제거'),
        content: Text('`${block.title}` 블록을 오늘 할 일에서만 제외할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('제외'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    final repo = ref.read(planningRepositoryProvider);
    final nextIds = visibleBlocks
        .where((b) => b.id != block.id && b.isSelectedForToday)
        .map((b) => b.id)
        .toList();
    await repo.setSelectedForToday(todayDateKey(), nextIds);
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('오늘 할 일에서 제외했어요.')),
    );
  }

  Future<void> _setAsCurrentTask(BuildContext context, WidgetRef ref, TaskBlock block) async {
    await ref.read(planningRepositoryProvider).setCurrentTask(block.id);
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('현재 작업으로 지정했어요.')),
    );
  }

  Future<void> _editTodayChecklist(BuildContext context, WidgetRef ref, TaskBlock block) async {
    final controllers = block.units
        .take(4)
        .map((u) => TextEditingController(text: u.title))
        .toList();
    if (controllers.isEmpty) {
      controllers.add(TextEditingController(text: '준비 60초'));
    }
    final uuid = const Uuid();
    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('체크리스트 수정', style: Theme.of(sheetContext).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (var i = 0; i < controllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controllers[i],
                              decoration: InputDecoration(
                                labelText: '단계 ${i + 1}',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: controllers.length <= 1
                                ? null
                                : () {
                                    setSheetState(() {
                                      controllers[i].dispose();
                                      controllers.removeAt(i);
                                    });
                                  },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: controllers.length >= 4
                          ? null
                          : () {
                              setSheetState(() {
                                controllers.add(TextEditingController());
                              });
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('단계 추가'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: const Text('저장'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      for (final c in controllers) {
        c.dispose();
      }
      return;
    }

    final raw = controllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    for (final c in controllers) {
      c.dispose();
    }
    if (raw.isEmpty) return;

    final nextUnits = <TaskUnit>[];
    for (var i = 0; i < raw.length && i < 4; i++) {
      if (i < block.units.length) {
        nextUnits.add(block.units[i].copyWith(title: raw[i]));
      } else {
        nextUnits.add(TaskUnit(id: uuid.v4(), title: raw[i]));
      }
    }
    await ref.read(planningRepositoryProvider).updateBlock(block.copyWith(units: nextUnits));
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('체크리스트를 수정했어요.')),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}