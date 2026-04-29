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
  });

  final TaskBlock block;
  final bool selected;
  final bool disabled;
  final bool maxReached;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final effectiveDisabled = disabled || (!selected && maxReached);
    final completed = block.isFullyComplete;
    final doneBg = const Color(0xFF80B3F6);
    final doneText = Colors.white;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: completed ? doneBg : null,
      child: CheckboxListTile(
        value: selected,
        activeColor: completed ? Colors.white : null,
        checkColor: completed ? doneBg : null,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: effectiveDisabled ? null : (v) => onChanged(v ?? false),
        title: Text(
          block.title,
          style: TextStyle(color: completed ? doneText : null),
        ),
        subtitle: Text(
          '단계 ${block.units.length}개',
          style: TextStyle(color: completed ? doneText.withValues(alpha: 0.95) : null),
        ),
        secondary: onDelete == null
            ? null
            : PopupMenuButton<String>(
                tooltip: '더보기',
                icon: Icon(Icons.more_vert, color: completed ? doneText : null),
                onSelected: (value) {
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('삭제'),
                  ),
                ],
              ),
      ),
    );
  }
}

