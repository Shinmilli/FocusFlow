import 'package:flutter/material.dart';

import '../../domain/task_block.dart';

class TaskBlockCard extends StatefulWidget {
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
  State<TaskBlockCard> createState() => _TaskBlockCardState();
}

class _TaskBlockCardState extends State<TaskBlockCard> {
  bool _showCompletedDetails = false;

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final completed = block.isFullyComplete;
    final showDetails = !completed || _showCompletedDetails;
    final doneBg = const Color(0xFF80B3F6);
    final doneText = Colors.white;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: completed ? doneBg : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: completed
                  ? () => setState(() => _showCompletedDetails = !_showCompletedDetails)
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      block.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: completed ? doneText : null,
                          ),
                    ),
                  ),
                  if (completed)
                    Icon(
                      showDetails ? Icons.expand_less : Icons.expand_more,
                      color: doneText,
                    ),
                  if (widget.onDecompose != null)
                    IconButton(
                      tooltip: 'AI로 더 쪼개기',
                      onPressed: widget.onDecompose,
                      icon: Icon(
                        Icons.auto_awesome,
                        color: completed ? doneText : null,
                      ),
                    ),
                ],
              ),
            ),
            if (showDetails) ...[
              const SizedBox(height: 8),
              ...block.units.map(
                (u) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: completed ? Colors.white : null,
                  checkColor: completed ? doneBg : null,
                  value: u.isDone,
                  title: Text(
                    u.title,
                    style: TextStyle(color: completed ? doneText : null),
                  ),
                  onChanged: (v) => widget.onToggleUnitDone(u.id, v ?? false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

