import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_agent/domain/agent_intervention.dart';
import '../../ai_agent/presentation/ai_providers.dart';
import '../../planning/presentation/planning_providers.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../../focus_session/presentation/focus_log_providers.dart';

final todaySummaryProvider = FutureProvider<String>((ref) async {
  final agent = ref.read(aiAgentServiceProvider);
  final ctx = ref.read(userLifeContextProvider);

  final blocks = await ref.read(todayBlocksProvider.future);
  final done = blocks.where((b) => b.isFullyComplete).length;
  final derived = await ref.read(derivedSignalsProvider.future);

  return agent.summarizeToday(
    context: ctx,
    blocksDone: done,
    blocksTotal: blocks.length,
    signals: SessionSignals(
      minutesToStart: derived.minutesToStart,
      ignoredNotifications: derived.ignoredNotifications,
    ),
  );
});

