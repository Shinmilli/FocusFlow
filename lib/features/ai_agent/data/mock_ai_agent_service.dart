import '../../planning/domain/task_block.dart';
import '../../planning/domain/task_unit.dart';
import '../../user_state/domain/user_life_context.dart';
import '../domain/agent_intervention.dart';
import '../domain/ai_agent_service.dart';

/// LLM 자리: 데모 문구만. API 키 연동 시 이 클래스를 대체/감싸면 됨.
class MockAiAgentService implements AiAgentService {
  @override
  Future<AgentPlanProposal> buildTodayPlan({
    required UserLifeContext context,
    required List<String> userStatedTasks,
    required List<TaskBlock> currentBacklog,
  }) async {
    final m = context.planIntensityMultiplier;
    final soft = m < 0.85;
    final msg = soft
        ? '오늘은 컨디션상 많이 못 할 수 있어요. '
            '가장 작은 한 덩어리만 15분 안에 끝나게 쪼개서 시작해 볼까요?'
        : '오늘 할 일을 우선순위로 정리했어요. 먼저 부담 적은 것부터 25분만 집중해 봐요.';

    final suggested = <TaskBlock>[];
    if (userStatedTasks.isNotEmpty) {
      for (final t in userStatedTasks.take(3)) {
        suggested.add(
          TaskBlock(
            id: 'ai-${t.hashCode}',
            title: t,
            units: [
              TaskUnit(id: 'u1', title: '준비 2분'),
              TaskUnit(id: 'u2', title: '핵심만 10분'),
              TaskUnit(id: 'u3', title: '마무리 3분'),
            ],
          ),
        );
      }
    }

    return AgentPlanProposal(
      messageForUser: msg,
      suggestedBlocks: suggested,
      actions: [
        if (context.phoneHeavyUse)
          const AgentAction(
            kind: AgentActionKind.adjustReminders,
            summary: '늦은 밤 스크린 타임 제한 알림을 켜는 걸 제안해요.',
          ),
        if (context.burnoutRisk)
          const AgentAction(
            kind: AgentActionKind.crisisResource,
            summary: '몇 주 지속되면 상담 센터 정보를 보여줄 수 있어요. (MCP 연동 예정)',
          ),
      ],
    );
  }

  @override
  Future<List<TaskUnit>> decomposeTask({
    required String taskTitle,
    required UserLifeContext context,
  }) async {
    final t = taskTitle.trim();
    if (t.isEmpty) return [];

    // 간단한 휴리스틱 + 컨디션 반영(컨디션 안 좋으면 더 작은 첫 단계 위주)
    final soft = context.planIntensityMultiplier < 0.85;

    List<String> steps;
    if (t.contains('과제') || t.contains('레포트') || t.contains('제출')) {
      steps = const ['자료 찾기', '목차/핵심 정리', '첫 문단(또는 개요) 쓰기', '제출/업로드'];
    } else if (t.contains('정리') || t.contains('청소')) {
      steps = const ['타이머 5분 켜기', '눈에 보이는 10개만 정리', '쓰레기만 버리기', '사진으로 완료 기록'];
    } else if (t.contains('공부') || t.contains('시험') || t.contains('암기')) {
      steps = const ['교재/노트 펼치기', '10분만 훑기', '핵심 3개만 적기', '5분 복습'];
    } else {
      steps = const ['준비 2분', '핵심만 10분', '마무리 3분'];
    }

    if (soft) {
      // "시작 유도"에 맞게 첫 단계 더 작게
      steps = [
        '준비 60초 (물/자리/도구)',
        ...steps.take(2),
      ];
    }

    return [
      for (var i = 0; i < steps.length; i++)
        TaskUnit(
          id: 'u-${t.hashCode}-$i',
          title: steps[i],
        ),
    ];
  }

  @override
  Future<String> explainFailure({
    required UserLifeContext context,
    required SessionSignals signals,
  }) async {
    final parts = <String>[];
    if (signals.minutesToStart > 20) {
      parts.add('시작까지 시간이 길었어요. 다음엔 더 작은 첫 단계만 잡아볼까요?');
    }
    if (signals.ignoredNotifications >= 5) {
      parts.add('알림을 여러 번 놓쳤어요. 알림 수나 방식을 바꾸는 게 도움이 될 수 있어요.');
    }
    if (context.sleepHours < 6) {
      parts.add('수면이 부족하면 오전 집중이 떨어져요. 오늘 오전 블록은 가볍게 가져가요.');
    }
    if (parts.isEmpty) {
      return '패턴을 더 모으면 원인 설명이 정확해져요. 오늘은 한 가지 작은 것만 완료해도 충분해요.';
    }
    return parts.join(' ');
  }

  @override
  Future<String> nudgeBackFromDistraction({
    required String currentTaskTitle,
    required UserLifeContext context,
  }) async {
    return '딴생각 허용! 10초만 "$currentTaskTitle"의 다음 한 줄만 보고 다시 시작할까요?';
  }

  @override
  Future<String> summarizeToday({
    required UserLifeContext context,
    required int blocksDone,
    required int blocksTotal,
    required SessionSignals signals,
  }) async {
    final parts = <String>[];
    parts.add('오늘 완료: $blocksDone / $blocksTotal 블록');

    if (signals.minutesToStart >= 20) {
      parts.add('시작 지연이 길었어요(≈${signals.minutesToStart}분). 내일은 “준비 60초” 같은 더 작은 시작을 추천해요.');
    } else if (signals.minutesToStart > 0) {
      parts.add('시작 지연은 약 ${signals.minutesToStart}분이었어요.');
    }

    if (signals.ignoredNotifications >= 3) {
      parts.add('이탈/딴생각 신호가 ${signals.ignoredNotifications}회 있었어요. 내일은 블록을 더 짧게(10–15분 단위) 잡아볼래요.');
    }

    if (context.sleepHours < 6) {
      parts.add('수면이 부족하면 오전 집중이 떨어져요. 내일 오전 블록은 가벼운 것으로 배치하는 게 좋아요.');
    }
    if (context.burnoutRisk) {
      parts.add('번아웃 위험 신호가 있어요. “완료 1개면 성공” 기준으로 강도를 낮춰요.');
    }

    if (parts.length == 1) {
      parts.add('좋아요. 내일도 “딱 1단계만”으로 계속 이어가면 충분해요.');
    }

    return parts.join('\n');
  }
}
