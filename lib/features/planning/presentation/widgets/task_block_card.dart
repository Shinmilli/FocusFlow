import 'package:flutter/material.dart';

import '../../domain/task_block.dart';

class TaskBlockCard extends StatefulWidget {
  const TaskBlockCard({
    super.key,
    required this.block,
    required this.onToggleUnitDone,
    this.onDecompose,
    this.onDelete,
    this.onEditChecklist,
    this.onSetCurrentTask,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final TaskBlock block;
  final void Function(String unitId, bool done) onToggleUnitDone;
  final VoidCallback? onDecompose;
  final VoidCallback? onDelete;
  final VoidCallback? onEditChecklist;
  final VoidCallback? onSetCurrentTask;
  final EdgeInsetsGeometry margin;

  @override
  State<TaskBlockCard> createState() => _TaskBlockCardState();
}

class _TaskBlockCardState extends State<TaskBlockCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.block.isCurrentTask;
  }

  @override
  void didUpdateWidget(covariant TaskBlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.block.isCurrentTask && widget.block.isCurrentTask) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final completed = block.isFullyComplete;
    final current = block.isCurrentTask;
    final showDetails = !completed || block.isCurrentTask || _expanded;
    final doneBg = const Color(0xFF80B3F6);
    final doneText = Colors.white;
    final currentBg = Theme.of(context).colorScheme.primary;
    final cardColor = completed
        ? doneBg
        : current
            ? currentBg
            : null;
    final foreground = (completed || current) ? doneText : null;

    return Card(
      margin: widget.margin,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (block.isCurrentTask && !completed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '현재 작업',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
            ],
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: block.isCurrentTask ? null : () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      block.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: foreground,
                          ),
                    ),
                  ),
                  if (!completed &&
                      (widget.onDelete != null ||
                          widget.onEditChecklist != null ||
                          widget.onSetCurrentTask != null))
                    PopupMenuButton<String>(
                      tooltip: '더보기',
                      padding: const EdgeInsets.all(2),
                      iconSize: 18,
                      icon: Icon(Icons.more_vert, color: foreground),
                      onSelected: (value) {
                        if (value == 'delete') widget.onDelete?.call();
                        if (value == 'edit') widget.onEditChecklist?.call();
                        if (value == 'current') widget.onSetCurrentTask?.call();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('삭제하기'),
                        ),
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('수정하기'),
                        ),
                        PopupMenuItem<String>(
                          value: 'current',
                          child: Text('현재 작업으로'),
                        ),
                      ],
                    ),
                  if (!completed && widget.onDecompose != null)
                    IconButton(
                      tooltip: 'AI로 더 쪼개기',
                      onPressed: widget.onDecompose,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: foreground,
                      ),
                    ),
                ],
              ),
            ),
            if (showDetails) ...[
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: block.units
                        .map(
                          (u) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            activeColor: completed ? Colors.white : null,
                            checkColor: completed ? doneBg : null,
                            value: u.isDone,
                            title: Text(
                              u.title,
                              style: TextStyle(color: foreground),
                            ),
                            onChanged: (v) => widget.onToggleUnitDone(u.id, v ?? false),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

