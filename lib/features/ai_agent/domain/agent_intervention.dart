import '../../planning/domain/task_block.dart';

/// LLM이 제안하는 실행 개입(일정 수정, 알림, 더 쪼개기 등).
enum AgentActionKind {
  reprioritize,
  shrinkTasks,
  adjustReminders,
  suggestRest,
  crisisResource,
  encouragement,
}

class AgentAction {
  const AgentAction({
    required this.kind,
    required this.summary,
    this.detail = '',
  });

  final AgentActionKind kind;
  final String summary;
  final String detail;
}

class AgentPlanProposal {
  const AgentPlanProposal({
    required this.messageForUser,
    required this.suggestedBlocks,
    this.actions = const [],
  });

  final String messageForUser;
  final List<TaskBlock> suggestedBlocks;
  final List<AgentAction> actions;
}

/// 실패·무시 패턴 등(추후 로그에서 채움).
class SessionSignals {
  const SessionSignals({
    this.ignoredNotifications = 0,
    this.minutesToStart = 0,
  });

  final int ignoredNotifications;
  final int minutesToStart;
}
