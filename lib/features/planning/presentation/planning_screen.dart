import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/focus_flow_limits.dart';
import '../../ai_agent/presentation/ai_providers.dart';
import '../../focus_session/domain/focus_log_event.dart';
import '../../focus_session/presentation/focus_log_providers.dart';
import '../../gamification/presentation/gamification_providers.dart';
import '../../gamification/domain/player_progress.dart';
import '../../user_state/presentation/user_context_providers.dart';
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
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push('/focus'),
                icon: const Icon(Icons.timer_outlined),
                label: Text(lowEnergy ? '딱 5분만 시작' : '집중 시작'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('오늘', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(width: 8),
                  Text(
                    '최대 ${FocusFlowLimits.maxSelectableBlocksPerDay}개',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          );

          if (blocks.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
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
                        const Text('과부하를 막기 위해 오늘은 최대 3개만 선택해요.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.push('/plan/select'),
                          icon: const Icon(Icons.checklist_rtl_outlined),
                          label: const Text('오늘 3개 고르기'),
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
                const SizedBox(height: 12),
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
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              top,
              for (final b in blocks)
                TaskBlockCard(
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
                ),
            ],
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