import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../coach/presentation/coach_nudge_controller.dart';
import '../../focus_session/presentation/focus_log_providers.dart';
import '../../goals/presentation/goals_providers.dart';
import '../../planning/domain/task_block.dart';
import '../../planning/domain/task_unit.dart';
import '../../planning/presentation/planning_providers.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../domain/agent_intervention.dart';
import 'ai_providers.dart';

/// 홈·프로필 등에서 공통으로 쓰는 “오늘 계획” AI 다이얼로그 (추천 블록 적용 포함).
Future<void> openAiTodayPlanProposal(BuildContext context, WidgetRef ref) async {
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

/// 시작 지연·알림 이탈 등을 바탕으로 한 AI 짧은 컨설팅 문구.
Future<void> openAiFailurePatternConsulting(BuildContext context, WidgetRef ref) async {
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

/// 프로필 등에서 AI 관련 기능을 한곳에서 고르게 열어 줍니다.
Future<void> showAiAssistantHub(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text('AI 도우미', style: Theme.of(context).textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  '오늘 계획 추천, 패턴 컨설팅, 일 쪼개기까지 한곳에서 연결해요.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('오늘 계획 제안'),
                subtitle: const Text('목표·오늘 블록·백로그 기반 추천과 적용'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  openAiTodayPlanProposal(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.psychology_outlined),
                title: const Text('실패 패턴 해석'),
                subtitle: const Text('미루기·이탈 신호를 바탕으로 한 짧은 컨설팅'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  openAiFailurePatternConsulting(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.splitscreen_outlined),
                title: const Text('큰 일을 작은 단계로'),
                subtitle: const Text('새 블록에서 AI로 체크리스트 만들기'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  context.push('/plan/add');
                },
              ),
              ListTile(
                leading: const Icon(Icons.query_stats_outlined),
                title: const Text('기록·통계'),
                subtitle: const Text('오늘 요약과 흐름 보기'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  context.push('/insights');
                },
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: const Text('상황 맞춤 코치 한마디'),
                subtitle: const Text('지금 띄울 만한 자동 제안이 있으면 표시'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await showCoachNudgeIfAny(context: context, ref: ref);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
