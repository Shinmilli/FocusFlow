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
  });

  final TaskBlock block;
  final bool selected;
  final bool disabled;
  final bool maxReached;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveDisabled = disabled || (!selected && maxReached);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: CheckboxListTile(
        value: selected,
        onChanged: effectiveDisabled ? null : (v) => onChanged(v ?? false),
        title: Text(block.title),
        subtitle: Text('단계 ${block.units.length}개'),
      ),
    );
  }
}

