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
import '../../user_state/presentation/user_context_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../goals/presentation/goals_providers.dart';
import '../../notifications/presentation/notification_providers.dart';
import 'widgets/daily_reminder_card.dart';
import 'widgets/xp_strip.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playerProgressProvider);
    final ctx = ref.watch(userLifeContextProvider);
    final lowEnergy = ctx.sleepHours < 6 || ctx.stressLevel >= 4;
    final asyncGoals = ref.watch(goalsProvider);

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
            '지금은 “다음 한 단계”만.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '계획 강도 ×${ctx.planIntensityMultiplier.toStringAsFixed(2)} · 수면 ${ctx.sleepHours.toStringAsFixed(1)}h · 스트레스 ${ctx.stressLevel}/5',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (lowEnergy)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '컨디션이 낮은 날이에요. 오늘은 5분부터 시작해도 충분해요.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          if (lowEnergy) const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push('/focus'),
            icon: const Icon(Icons.timer_outlined),
            label: Text(lowEnergy ? '딱 5분만 시작' : '집중 시작'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/plan'),
            icon: const Icon(Icons.view_agenda_outlined),
            label: const Text('오늘 블록 (최대 3개)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push('/context'),
            icon: const Icon(Icons.tune),
            label: const Text('오늘 상태 조정'),
          ),
          const SizedBox(height: 18),
          XpStrip(progress: progress),
          const SizedBox(height: 12),
          const DailyReminderCard(),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('더 보기'),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              ListTile(
                leading: const Icon(Icons.query_stats_outlined),
                title: const Text('기록/통계'),
                onTap: () => context.push('/insights'),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('프로필'),
                subtitle: const Text('로그인/닉네임/레벨'),
                onTap: () => context.push('/profile'),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('목표'),
                subtitle: Text(
                  asyncGoals.when(
                    data: (g) => g.isEmpty ? '아직 없음' : '${g.length}개',
                    loading: () => '불러오는 중…',
                    error: (_, __) => '불러오기 실패',
                  ),
                ),
                onTap: () => context.push('/goals'),
              ),
              ListTile(
                leading: const Icon(Icons.people_alt_outlined),
                title: const Text('바디 더블링'),
                subtitle: const Text('혼자 하기 어렵다면 같이 시작'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('AI: 오늘 계획 제안'),
                onTap: () => _runAiCoach(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.insights_outlined),
                title: const Text('AI: 실패 패턴 해석'),
                onTap: () => _runFailureExplain(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: const Text('외부 도구 (MCP 데모)'),
                onTap: () => context.push('/mcp'),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('리마인더 테스트(로컬)'),
                onTap: () => showTestReminder(ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _runAiCoach(BuildContext context, WidgetRef ref) async {
    final life = ref.read(userLifeContextProvider);
    final agent = ref.read(aiAgentServiceProvider);
    final repo = ref.read(planningRepositoryProvider);
    final goals = await ref.read(goalsProvider.future);
    final dateKey = todayDateKey();

    final todayBlocks = await repo.loadTodayVisibleBlocks(dateKey);
    final backlog = await repo.loadBacklog();
    final userStated = <String>[
      ...goals,
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
