import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../ai_agent/presentation/ai_assistant_hub.dart';
import '../../ai_agent/presentation/ai_providers.dart';
import '../../coach/presentation/coach_nudge_controller.dart';
import '../../focus_session/domain/focus_log_event.dart';
import '../../focus_session/presentation/focus_log_providers.dart';
import '../../gamification/presentation/gamification_providers.dart';
import '../../../app/theme/app_chrome.dart';
import '../../home/presentation/widgets/today_project_hero.dart';
import '../../home/presentation/widgets/today_task_grid_card.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../domain/task_block.dart';
import '../domain/task_unit.dart';
import 'planning_providers.dart';

/// 오늘 블록 — 홈「오늘의 프로젝트」와 동일한 히어로·카드 디자인, 편집 기능 포함.
class PlanningScreen extends ConsumerWidget {
  const PlanningScreen({super.key});

  /// 홈 그리드와 동일: 단계는 처음부터 체크리스트(탭 완료), 더보기 메뉴 포함.
  static Widget taskGridCard(BuildContext context, WidgetRef ref, TaskBlock b) =>
      _planningCard(context, ref, b);

  static List<TaskBlock> _orderedBlocks(List<TaskBlock> blocks) {
    final current = blocks.where((b) => b.isCurrentTask).toList();
    final incomplete = blocks.where((b) => !b.isFullyComplete && !b.isCurrentTask).toList();
    final complete = blocks.where((b) => b.isFullyComplete && !b.isCurrentTask).toList();
    return [...current, ...incomplete, ...complete];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBlocks = ref.watch(todayBlocksProvider);
    final progress = ref.watch(playerProgressProvider);
    final ctx = ref.watch(userLifeContextProvider);
    final lowEnergy = ctx.sleepHours < 6 || ctx.stressLevel >= 4;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCoachNudgeIfAny(context: context, ref: ref);
    });

    void refreshPlanning() {
      ref.invalidate(todayBlocksProvider);
      ref.invalidate(backlogBlocksProvider);
      ref.invalidate(canAddNewBlockProvider);
    }

    final heroActions = <Widget>[
      IconButton(
        tooltip: '새로고침',
        onPressed: refreshPlanning,
        icon: Icon(Icons.refresh, color: Colors.white.withValues(alpha: 0.92)),
        visualDensity: VisualDensity.compact,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TodayProjectHero(
            progress: progress,
            lowEnergy: lowEnergy,
            onStartFocus: () => context.push('/focus'),
            leadingActions: heroActions,
          ),
          Expanded(
            child: asyncBlocks.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (blocks) {
                final list = _orderedBlocks(blocks);
                if (list.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    children: [
                      Text(
                        '오늘 블록이 비어 있어요',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text('오늘 할 블록을 선택해 시작해요.'),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final agent = ref.read(aiAgentServiceProvider);
                          final life = ref.read(userLifeContextProvider);
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
                              context: life,
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
                  );
                }

                return CustomScrollView(
                  slivers: [
                    if (lowEnergy)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                '컨디션이 낮은 날이에요. 오늘은 5분부터 시작해도 충분해요.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 36)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childCount: list.length,
                        itemBuilder: (context, index) {
                          return PlanningScreen.taskGridCard(context, ref, list[index]);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _BottomAction(
                      icon: Icons.date_range_outlined,
                      label: '주간',
                      onTap: () => context.push('/plan/week'),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
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
                    _BottomAction(
                      icon: Icons.person_outline,
                      label: '프로필',
                      onTap: () => context.go('/profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _planningCard(BuildContext context, WidgetRef ref, TaskBlock b) {
    return TodayTaskGridCard(
      block: b,
      onTap: () {},
      onSparkle: () => openAiTodayPlanProposal(context, ref),
      onToggleUnitDone: (unitId, done) async {
              final repo = ref.read(planningRepositoryProvider);
              final wasAllDone = b.units.every((u) => u.isDone);
              final updatedUnits =
                  b.units.map((u) => u.id == unitId ? u.copyWith(isDone: done) : u).toList();
              final nowAllDone = updatedUnits.every((u) => u.isDone);
              await repo.updateBlock(b.copyWith(units: updatedUnits));
              ref.invalidate(todayBlocksProvider);
              ref.invalidate(backlogBlocksProvider);
              ref.invalidate(canAddNewBlockProvider);
              if (!wasAllDone && nowAllDone) {
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
      onEditChecklist: () => _editTodayChecklist(context, ref, b),
      onSetCurrentTask: b.isFullyComplete ? null : () => _setAsCurrentTask(context, ref, b),
      onDecompose: b.isFullyComplete
          ? null
          : () async {
              final agent = ref.read(aiAgentServiceProvider);
              final life = ref.read(userLifeContextProvider);
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
                  context: life,
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
      onDelete: () => _confirmDeleteBlock(context, ref, b),
    );
  }

  static Future<void> _confirmDeleteBlock(BuildContext context, WidgetRef ref, TaskBlock block) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('블록 삭제'),
        content: Text(
          '`${block.title}` 블록을 완전히 삭제할까요?\n'
          '오늘·백로그·다른 날짜 선택에서도 모두 사라져요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    await ref.read(planningRepositoryProvider).deleteBlock(block.id);
    final key = todayDateKey();
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
    ref.invalidate(blocksForDateProvider(key));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('블록을 삭제했어요.')),
    );
  }

  static Future<void> _setAsCurrentTask(BuildContext context, WidgetRef ref, TaskBlock block) async {
    await ref.read(planningRepositoryProvider).setCurrentTask(block.id);
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
    ref.invalidate(blocksForDateProvider(todayDateKey()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('현재 작업으로 지정했어요.')),
    );
  }

  static Future<void> _editTodayChecklist(BuildContext context, WidgetRef ref, TaskBlock block) async {
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
                    style: AppChrome.primaryActionNavyStyle,
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
