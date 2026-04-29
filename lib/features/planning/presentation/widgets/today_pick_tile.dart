import 'package:flutter/material.dart';

import '../../domain/task_block.dart';

class TodayPickTile extends StatelessWidget {
  const TodayPickTile({
    super.key,
    required this.block,
    required this.selected,
    required this.disabled,
    required this.maxReached,
    required this.onChanged,
    this.onDelete,
    this.onEditChecklist,
    this.onSetCurrentTask,
  });

  final TaskBlock block;
  final bool selected;
  final bool disabled;
  final bool maxReached;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onEditChecklist;
  final VoidCallback? onSetCurrentTask;

  @override
  Widget build(BuildContext context) {
    final effectiveDisabled = disabled || (!selected && maxReached);
    final completed = block.isFullyComplete;
    final current = block.isCurrentTask;
    final doneBg = const Color(0xFF80B3F6);
    final doneText = Colors.white;
    final currentBg = Theme.of(context).colorScheme.primary;
    final currentTitle = Colors.white;
    final cardColor = current
        ? currentBg
        : completed
            ? doneBg
            : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: cardColor,
      child: CheckboxListTile(
        value: selected,
        activeColor: completed ? Colors.white : null,
        checkColor: completed ? doneBg : null,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: effectiveDisabled ? null : (v) => onChanged(v ?? false),
        title: Text(
          block.title,
          style: TextStyle(
            color: completed
                ? doneText
                : current
                    ? currentTitle
                    : null,
          ),
        ),
        subtitle: Text(
          '단계 ${block.units.length}개',
          style: TextStyle(
            color: completed
                ? doneText.withValues(alpha: 0.95)
                : current
                    ? doneText.withValues(alpha: 0.9)
                    : null,
          ),
        ),
        secondary: (onDelete == null && onEditChecklist == null && onSetCurrentTask == null)
            ? null
            : PopupMenuButton<String>(
                tooltip: '더보기',
                icon: Icon(
                  Icons.more_vert,
                  color: completed || current ? doneText : null,
                ),
                onSelected: (value) {
                  if (value == 'delete') onDelete?.call();
                  if (value == 'edit') onEditChecklist?.call();
                  if (value == 'current') onSetCurrentTask?.call();
                },
                itemBuilder: (_) => [
                  if (onSetCurrentTask != null)
                    const PopupMenuItem<String>(
                      value: 'current',
                      child: Text('현재 작업으로'),
                    ),
                  if (onEditChecklist != null)
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('체크리스트 수정'),
                    ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('삭제'),
                  ),
                ],
              ),
      ),
    );
  }
}

