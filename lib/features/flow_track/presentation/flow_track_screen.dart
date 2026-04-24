import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/flow_week_segment.dart';
import 'flow_track_providers.dart';

class FlowTrackScreen extends ConsumerWidget {
  const FlowTrackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSegs = ref.watch(flowWeekSegmentsProvider);
    final asyncTarget = ref.watch(flowWeeklyTargetProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('플로우 트랙'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: () {
              ref.invalidate(flowWeekSegmentsProvider);
              ref.invalidate(flowWeeklyTargetProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: asyncTarget.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (t) => Text(
                  '주간 목표: $t회 이상 집중 성공',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          asyncSegs.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.only(top: 24),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => Center(child: Text('$e')),
            data: (segs) {
              if (segs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('아직 집중 기록이 없어요. 집중을 완료하면 트랙이 쌓여요.'),
                  ),
                );
              }

              // 최신 주가 위에, 과거는 아래로 스크롤.
              final view = segs.reversed.toList();
              return Column(
                children: [
                  for (final s in view) _FlowWeekTile(segment: s),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FlowWeekTile extends StatelessWidget {
  const _FlowWeekTile({required this.segment});

  final FlowWeekSegment segment;

  @override
  Widget build(BuildContext context) {
    final lineColor = segment.success
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outlineVariant;
    final textTone = segment.success ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    segment.tier,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'W${segment.weekKey.split('-').last}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textTone),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    segment.weekStartDateKey,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 26,
              child: _TrackGlyph(
                solid: segment.success,
                repair: segment.repairMark,
                color: lineColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    segment.success ? '성공' : '빈 구간',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: segment.success ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '집중 완료 ${segment.completedCount} / ${segment.weeklyTarget}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '연속 성공 ${segment.streakWeeks}주 · 게이지 ${(segment.masteryGauge * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackGlyph extends StatelessWidget {
  const _TrackGlyph({
    required this.solid,
    required this.repair,
    required this.color,
  });

  final bool solid;
  final bool repair;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dim = Theme.of(context).colorScheme.outlineVariant;

    Widget line;
    if (solid) {
      line = Container(
        width: 4,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    } else {
      // dashed
      line = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 7; i++)
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: dim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      );
    }

    return Column(
      children: [
        line,
        if (repair) ...[
          const SizedBox(height: 6),
          Icon(Icons.handyman_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ],
    );
  }
}

