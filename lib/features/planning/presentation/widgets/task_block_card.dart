import 'package:flutter/material.dart';

import '../../domain/task_block.dart';

class TaskBlockCard extends StatelessWidget {
  const TaskBlockCard({
    super.key,
    required this.block,
    required this.onToggleUnitDone,
    this.onDecompose,
  });

  final TaskBlock block;
  final void Function(String unitId, bool done) onToggleUnitDone;
  final VoidCallback? onDecompose;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    block.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onDecompose != null)
                  IconButton(
                    tooltip: 'AI로 더 쪼개기',
                    onPressed: onDecompose,
                    icon: const Icon(Icons.auto_awesome),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...block.units.map(
              (u) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: u.isDone,
                title: Text(u.title),
                onChanged: (v) => onToggleUnitDone(u.id, v ?? false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

