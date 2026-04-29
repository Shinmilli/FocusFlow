import 'package:flutter/material.dart';

class TodaySelectHeader extends StatelessWidget {
  const TodaySelectHeader({
    super.key,
    required this.selectedCount,
  });

  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '오늘: $selectedCount개',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '오늘 할 블록을 자유롭게 고를 수 있어요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

