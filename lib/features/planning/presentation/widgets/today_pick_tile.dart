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
  });

  final TaskBlock block;
  final bool selected;
  final bool disabled;
  final bool maxReached;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onEditChecklist;

  @override
  Widget build(BuildContext context) {
    final effectiveDisabled = disabled || (!selected && maxReached);
    final completed = block.isFullyComplete;
    final current = block.isCurrentTask;
    final doneBg = const Color(0xFF80B3F6);
    final doneText = Colors.white;
    final currentBg = Colors.grey.shade200;
    final currentTitle = Theme.of(context).colorScheme.primary;
    final cardColor = completed
        ? doneBg
        : current
            ? currentBg
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
                    ? Colors.black54
                    : null,
          ),
        ),
        secondary: onDelete == null
            ? null
            : PopupMenuButton<String>(
                tooltip: '더보기',
                icon: Icon(Icons.more_vert, color: completed ? doneText : null),
                onSelected: (value) {
                  if (value == 'delete') onDelete?.call();
                  if (value == 'edit') onEditChecklist?.call();
                },
                itemBuilder: (_) => [
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

