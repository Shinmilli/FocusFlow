import 'package:flutter/material.dart';

import '../../../../core/constants/focus_flow_limits.dart';

class TodaySelectHeader extends StatelessWidget {
  const TodaySelectHeader({
    super.key,
    required this.selectedCount,
    required this.canAdd,
  });

  final int selectedCount;
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    final limit = FocusFlowLimits.maxSelectableBlocksPerDay;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '오늘: $selectedCount / $limit',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              canAdd
                  ? '과부하 방지를 위해 딱 3개만 고르고, 끝내면 다음으로 넘어가요.'
                  : '아직 끝나지 않은 블록이 있어요. 완료 전에는 다음 일을 추가하지 않아요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

