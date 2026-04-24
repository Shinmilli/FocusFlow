import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../focus_session/presentation/focus_log_providers.dart';
import '../data/flow_track_repository.dart';
import '../domain/flow_week_segment.dart';

final flowTrackRepositoryProvider = Provider<FlowTrackRepository>((ref) {
  return FlowTrackRepository();
});

final flowWeeklyTargetProvider = FutureProvider<int>((ref) async {
  return ref.read(flowTrackRepositoryProvider).weeklyTarget();
});

final flowWeekSegmentsProvider = FutureProvider<List<FlowWeekSegment>>((ref) async {
  final repo = ref.read(flowTrackRepositoryProvider);
  final events = await ref.watch(focusLogEventsProvider.future);
  return repo.buildSegmentsFromEvents(events);
});

