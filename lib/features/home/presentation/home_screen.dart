import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/api_config.dart';
import '../../ai_agent/domain/agent_intervention.dart';
import '../../ai_agent/presentation/ai_providers.dart';
import '../../focus_session/presentation/focus_log_providers.dart';
import '../../gamification/presentation/gamification_providers.dart';
import '../../planning/domain/task_block.dart';
import '../../planning/domain/task_unit.dart';
import '../../planning/presentation/planning_providers.dart';
import '../../start_nudge/presentation/body_doubling_card.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../notifications/presentation/notification_providers.dart';
import 'widgets/daily_reminder_card.dart';
import 'widgets/xp_strip.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playerProgressProvider);
    final ctx = ref.watch(userLifeContextProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusFlow'),
        actions: [
          if (kApiBaseUrlConfigured)
            IconButton(
              tooltip: '로그아웃',
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '실행이 어려울 때를 위한 계획 이행 도우미',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '오늘 계획 강도: ×${ctx.planIntensityMultiplier.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          XpStrip(progress: progress),
          const SizedBox(height: 16),
          const DailyReminderCard(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/plan'),
            icon: const Icon(Icons.view_agenda_outlined),
            label: const Text('오늘 블록 (최대 3개)'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/focus'),
            icon: const Icon(Icons.timer_outlined),
            label: const Text('집중 시작'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/context'),
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('수면·스트레스 등 상태'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/insights'),
            icon: const Icon(Icons.query_stats_outlined),
            label: const Text('기록/통계 보기'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/mcp'),
            icon: const Icon(Icons.hub_outlined),
            label: const Text('외부 도구 (MCP 데모)'),
          ),
          const SizedBox(height: 24),
          const BodyDoublingCard(),
          const SizedBox(height: 16),
          Text('Agentic AI', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _runAiCoach(context, ref),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('오늘 계획 제안 받기'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _runFailureExplain(context, ref),
            icon: const Icon(Icons.insights_outlined),
            label: const Text('실패 원인 설명 (데모)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => showTestReminder(ref),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('리마인더 테스트(로컬 알림)'),
          ),
        ],
      ),
    );
  }

  Future<void> _runAiCoach(BuildContext context, WidgetRef ref) async {
    final life = ref.read(userLifeContextProvider);
    final agent = ref.read(aiAgentServiceProvider);
    final repo = ref.read(planningRepositoryProvider);
    final dateKey = todayDateKey();

    final todayBlocks = await repo.loadTodayVisibleBlocks(dateKey);
    final backlog = await repo.loadBacklog();
    final userStated = <String>[
      ...todayBlocks.map((b) => b.title),
      ...backlog.map((b) => b.title),
    ].take(8).toList();

    final proposal = await agent.buildTodayPlan(
      context: life,
      userStatedTasks: userStated,
      currentBacklog: backlog,
    );
    if (!context.mounted) return;

    final max = 3;
    final remaining = (max - todayBlocks.length).clamp(0, max);
    final selectedIdx = <int>{};
    for (var i = 0; i < proposal.suggestedBlocks.length && selectedIdx.length < remaining; i++) {
      selectedIdx.add(i);
    }

    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('AI 제안'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(proposal.messageForUser),
              if (proposal.suggestedBlocks.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '추천 블록 (적용하면 백로그/오늘에 추가돼요)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder: (context, setState) {
                    return Column(
                      children: [
                        for (var i = 0; i < proposal.suggestedBlocks.length; i++)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: selectedIdx.contains(i),
                            title: Text(proposal.suggestedBlocks[i].title),
                            subtitle: Text('단계 ${proposal.suggestedBlocks[i].units.length}개'),
                            onChanged: (v) {
                              setState(() {
                                if (v ?? false) {
                                  if (selectedIdx.length < remaining) {
                                    selectedIdx.add(i);
                                  }
                                } else {
                                  selectedIdx.remove(i);
                                }
                              });
                            },
                          ),
                        if (remaining == 0)
                          Text(
                            '오늘 블록이 이미 $max개라서, 적용하면 백로그에만 추가돼요.',
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        else
                          Text(
                            '오늘에 넣을 블록: ${selectedIdx.length} / $remaining',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    );
                  },
                ),
              ],
              if (proposal.actions.isNotEmpty) const SizedBox(height: 12),
              ...proposal.actions.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• ${a.summary}'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final canAdd = await repo.canAddNewBlock(dateKey);
              if (!canAdd) {
                if (!c.mounted) return;
                ScaffoldMessenger.of(c).showSnackBar(
                  const SnackBar(content: Text('아직 끝나지 않은 블록이 있어요. 완료 후에 적용해요.')),
                );
                return;
              }

              final uuid = const Uuid();
              final existingTitles = <String>{
                ...todayBlocks.map((b) => b.title.trim()),
                ...backlog.map((b) => b.title.trim()),
              };

              final idByIndex = List<String?>.filled(
                proposal.suggestedBlocks.length,
                null,
              );

              for (var i = 0; i < proposal.suggestedBlocks.length; i++) {
                final b = proposal.suggestedBlocks[i];
                final baseTitle = b.title.trim();
                if (baseTitle.isEmpty) continue;

                var finalTitle = baseTitle;
                if (existingTitles.contains(finalTitle)) {
                  finalTitle = '$finalTitle (AI)';
                }
                existingTitles.add(finalTitle);

                final newBlock = TaskBlock(
                  id: uuid.v4(),
                  title: finalTitle,
                  units: [
                    for (final u in b.units)
                      TaskUnit(
                        id: uuid.v4(),
                        title: u.title.trim().isEmpty ? '다음 한 단계' : u.title,
                      ),
                  ],
                );

                await repo.addBlock(newBlock);
                idByIndex[i] = newBlock.id;
              }

              // 선택 적용: 오늘 남은 슬롯만큼만 추가.
              final nextTodayIds = [...todayBlocks.map((b) => b.id)];
              final sortedPick = selectedIdx.toList()..sort();
              for (final i in sortedPick) {
                if (nextTodayIds.length >= max) break;
                final id = (i >= 0 && i < idByIndex.length) ? idByIndex[i] : null;
                if (id == null) continue;
                if (!nextTodayIds.contains(id)) nextTodayIds.add(id);
              }

              if (nextTodayIds.length <= max && nextTodayIds.isNotEmpty) {
                await repo.setSelectedForToday(dateKey, nextTodayIds);
              }

              ref.invalidate(todayBlocksProvider);
              ref.invalidate(backlogBlocksProvider);
              ref.invalidate(canAddNewBlockProvider);

              if (!c.mounted) return;
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('적용했어요')),
              );
            },
            child: const Text('적용'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _runFailureExplain(BuildContext context, WidgetRef ref) async {
    final life = ref.read(userLifeContextProvider);
    final agent = ref.read(aiAgentServiceProvider);
    final derived = await ref.read(derivedSignalsProvider.future);
    final text = await agent.explainFailure(
      context: life,
      signals: SessionSignals(
        ignoredNotifications: derived.ignoredNotifications,
        minutesToStart: derived.minutesToStart,
      ),
    );
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('패턴 해석'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
