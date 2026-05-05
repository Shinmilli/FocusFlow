import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../flow_track/presentation/flow_track_providers.dart';
import '../focus_session/presentation/focus_log_providers.dart';
import '../gamification/presentation/gamification_providers.dart';
import '../goals/presentation/goals_providers.dart';
import '../planning/presentation/planning_providers.dart';

/// 동기화 pull 직후 로컬 Pref를 반영했으므로 관련 캐시를 무효화합니다.
void invalidateSyncedUserCaches(WidgetRef ref) {
  ref.invalidate(playerProgressProvider);
  ref.invalidate(todayBlocksProvider);
  ref.invalidate(backlogBlocksProvider);
  ref.invalidate(blocksForDateProvider);
  ref.invalidate(canAddNewBlockProvider);
  ref.invalidate(focusLogEventsProvider);
  ref.invalidate(derivedSignalsProvider);
  ref.invalidate(goalsProvider);
  ref.invalidate(flowWeekSegmentsProvider);
  ref.invalidate(flowWeeklyTargetProvider);
}
