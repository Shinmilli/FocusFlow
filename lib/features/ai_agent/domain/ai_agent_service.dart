import 'agent_intervention.dart';
import '../../planning/domain/task_block.dart';
import '../../planning/domain/task_unit.dart';
import '../../user_state/domain/user_life_context.dart';

/// 실제 앱에서는 여기서 OpenAI/Claude + 도구 호출(MCP)을 연결.
abstract class AiAgentService {
  Future<AgentPlanProposal> buildTodayPlan({
    required UserLifeContext context,
    required List<String> userStatedTasks,
    required List<TaskBlock> currentBacklog,
  });

  /// 큰 일을 작은 실행 단위로 자동 분해.
  Future<List<TaskUnit>> decomposeTask({
    required String taskTitle,
    required UserLifeContext context,
  });

  Future<String> explainFailure({
    required UserLifeContext context,
    required SessionSignals signals,
  });

  Future<String> nudgeBackFromDistraction({
    required String currentTaskTitle,
    required UserLifeContext context,
  });

  /// 오늘 실행 패턴을 한 문단으로 요약 + 내일 조정 제안.
  Future<String> summarizeToday({
    required UserLifeContext context,
    required int blocksDone,
    required int blocksTotal,
    required SessionSignals signals,
  });
}
