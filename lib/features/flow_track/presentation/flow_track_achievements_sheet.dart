import 'package:flutter/material.dart';

import '../data/flow_track_repository.dart';
import 'flow_track_tier_style.dart';

/// 플로우 트랙에서 노출 가능한 업적·티어 안내.
Future<void> showFlowTrackAchievementsDialog(BuildContext context) async {
  final milestones = FlowTrackRepository.tierMilestonesDescriptionRows();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('플로우 트랙 업적'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '주간 목표',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              '설정한 주간 목표 횟수만큼 이번 주에 집중 완료하면 타임라인에 파란 칩으로 표시돼요.',
            ),
            const SizedBox(height: 16),
            Text(
              '한 주를 놓친 뒤 다시 달성하면',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              '어두운 칩으로 “복귀”가 표시되고, 연속 주 수는 그때부터 다시 이어져요.',
            ),
            const SizedBox(height: 16),
            Text(
              '티어 (연속 목표 달성 주 수)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final row in milestones)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 88,
                      child: Text(
                        row.$1,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: FlowTrackTierStyle.accent(row.$1),
                        ),
                      ),
                    ),
                    Expanded(child: Text(row.$2)),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}
