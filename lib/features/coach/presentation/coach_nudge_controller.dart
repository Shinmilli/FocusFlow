import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ai_agent/presentation/ai_providers.dart';
import '../../ai_agent/domain/agent_intervention.dart';
import '../../focus_session/presentation/focus_log_providers.dart';
import '../../goals/presentation/goals_providers.dart';
import '../../planning/presentation/planning_providers.dart';
import '../../planning/domain/task_block.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../data/coach_nudge_prefs.dart';
import 'coach_nudge_providers.dart';

enum CoachNudgeDecisionType {
  aiTodayPlan,
  bodyDoubling,
  insightsSummary,
  failurePattern,
}

class CoachNudgeDecision {
  const CoachNudgeDecision(this.type);

  final CoachNudgeDecisionType type;
}

final coachNudgeDecisionProvider = FutureProvider<CoachNudgeDecision?>((ref) async {
  final prefs = ref.read(coachNudgePrefsProvider);
  final intensity = await prefs.intensity();

  Future<bool> allow(CoachNudgeType t) => prefs.canShowToday(t);

  final blocks = await ref.watch(todayBlocksProvider.future);
  final derived = await ref.watch(derivedSignalsProvider.future);

  // 1) If no blocks selected today, AI plan is highest priority.
  if (blocks.isEmpty && await allow(CoachNudgeType.aiTodayPlan)) {
    return const CoachNudgeDecision(CoachNudgeDecisionType.aiTodayPlan);
  }

  // 2) Body doubling when distractions pile up (active only).
  if (intensity == CoachNudgeIntensity.active &&
      derived.distractionCountToday >= 3 &&
      await allow(CoachNudgeType.bodyDoubling)) {
    return const CoachNudgeDecision(CoachNudgeDecisionType.bodyDoubling);
  }

  // 3) Failure pattern when start delay or ignored signals are high.
  final highStartDelay = derived.minutesToStart >= 20;
  final highIgnored = derived.ignoredNotifications >= 5;
  if ((highStartDelay || highIgnored) && await allow(CoachNudgeType.failurePattern)) {
    return const CoachNudgeDecision(CoachNudgeDecisionType.failurePattern);
  }

  // 4) Insights summary: only in active mode and later hours. Keep it rare.
  if (intensity == CoachNudgeIntensity.active) {
    final now = DateTime.now();
    if (now.hour >= 21 && await allow(CoachNudgeType.insightsSummary)) {
      final done = blocks.where((b) => b.isFullyComplete).length;
      if (done >= 1) {
        return const CoachNudgeDecision(CoachNudgeDecisionType.insightsSummary);
      }
    }
  }

  return null;
});

Future<void> showCoachNudgeIfAny({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  if (!context.mounted) return;

  final decision = await ref.read(coachNudgeDecisionProvider.future);
  if (decision == null) return;

  final prefs = ref.read(coachNudgePrefsProvider);

  switch (decision.type) {
    case CoachNudgeDecisionType.aiTodayPlan:
      await prefs.markShownToday(CoachNudgeType.aiTodayPlan);
      if (!context.mounted) return;
      await _showAiTodayPlanSheet(context: context, ref: ref);
      return;
    case CoachNudgeDecisionType.bodyDoubling:
      await prefs.markShownToday(CoachNudgeType.bodyDoubling);
      if (!context.mounted) return;
      await _showBodyDoublingSheet(context: context, ref: ref);
      return;
    case CoachNudgeDecisionType.insightsSummary:
      await prefs.markShownToday(CoachNudgeType.insightsSummary);
      if (!context.mounted) return;
      await _showInsightsSheet(context: context);
      return;
    case CoachNudgeDecisionType.failurePattern:
      await prefs.markShownToday(CoachNudgeType.failurePattern);
      if (!context.mounted) return;
      await _showFailurePatternSheet(context: context, ref: ref);
      return;
  }
}

Future<void> _showAiTodayPlanSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final agent = ref.read(aiAgentServiceProvider);
  final life = ref.read(userLifeContextProvider);
  final repo = ref.read(planningRepositoryProvider);
  final goals = await ref.read(goalsProvider.future);
  final backlog = await repo.loadBacklog();

  AgentPlanProposal? proposal;
  Object? err;
  try {
    proposal = await agent.buildTodayPlan(
      context: life,
      userStatedTasks: [...goals, ...backlog.map((b) => b.title)].take(8).toList(),
      currentBacklog: backlog,
    );
  } catch (e) {
    err = e;
  }

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('오늘은 이렇게 시작해 볼까요?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (err != null)
              Text('AI 제안을 불러오지 못했어요: $err')
            else ...[
              Text(proposal?.messageForUser ?? '오늘은 작은 한 단계만 해도 충분해요.'),
              const SizedBox(height: 8),
              if ((proposal?.suggestedBlocks ?? const <TaskBlock>[]).isNotEmpty)
                Text(
                  '추천: ${(proposal!.suggestedBlocks.first).title}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                context.push('/plan/select');
              },
              child: const Text('오늘 3개 고르러 가기'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('닫기'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showBodyDoublingSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('혼자 하기 어렵다면', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('지금은 “딱 5분만” 같이 시작하는 게 도움이 될 수 있어요.'),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(c);
                context.push('/focus');
              },
              icon: const Icon(Icons.timer_outlined),
              label: const Text('5분만 시작하기'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('나중에'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showInsightsSheet({required BuildContext context}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('오늘을 짧게 정리해 볼까요?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('2분이면 내일이 훨씬 쉬워져요.'),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                context.push('/insights');
              },
              child: const Text('오늘 요약 보기'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('닫기'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showFailurePatternSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final derived = await ref.read(derivedSignalsProvider.future);
  final text = '최근 시작 지연 ${derived.minutesToStart}분 · 오늘 이탈 ${derived.distractionCountToday}회\n'
      '다음엔 “준비 60초” 같은 더 작은 시작이 좋아요.';

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('패턴이 보여요', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(text),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                context.push('/focus');
              },
              child: const Text('지금 5분만 시작'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('닫기'),
            ),
          ],
        ),
      );
    },
  );
}

