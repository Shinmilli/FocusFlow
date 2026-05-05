import 'package:flutter/material.dart';

import '../../../../app/theme/app_chrome.dart';
import '../../domain/task_block.dart';

/// [weekPlan]: 주간 화면 — 할·백로그는 탭으로 계획에 넣고 빼기(체크박스 없음), 끝낸 항목만 체크 아이콘.
enum TodayPickTileVariant {
  standard,
  weekPlan,
}

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
    this.variant = TodayPickTileVariant.standard,
  });

  final TaskBlock block;
  final bool selected;
  final bool disabled;
  final bool maxReached;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onEditChecklist;
  final VoidCallback? onSetCurrentTask;
  final TodayPickTileVariant variant;

  @override
  Widget build(BuildContext context) {
    final effectiveDisabled = disabled || (!selected && maxReached);
    final completed = block.isFullyComplete;

    if (variant == TodayPickTileVariant.weekPlan) {
      return completed
          ? _buildWeekPlanDone(context)
          : _buildWeekPlanTodo(context, effectiveDisabled);
    }

    return _buildStandard(context, effectiveDisabled, completed);
  }

  PopupMenuButton<String> _weekPlanMenu(BuildContext context, {required bool showRemoveFromDay}) {
    return PopupMenuButton<String>(
      tooltip: '더보기',
      icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurfaceVariant),
      onSelected: (value) {
        if (value == 'delete') onDelete?.call();
        if (value == 'edit') onEditChecklist?.call();
        if (value == 'current') onSetCurrentTask?.call();
        if (value == 'remove_day') onChanged(false);
      },
      itemBuilder: (_) => [
        if (showRemoveFromDay)
          const PopupMenuItem<String>(
            value: 'remove_day',
            child: Text('이 날 계획에서 빼기'),
          ),
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
        if (onDelete != null)
          const PopupMenuItem<String>(
            value: 'delete',
            child: Text('삭제'),
          ),
      ],
    );
  }

  Widget _buildWeekPlanTodo(BuildContext context, bool effectiveDisabled) {
    final hasMenu = onDelete != null || onEditChecklist != null || onSetCurrentTask != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppChrome.softCard(context),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppChrome.softBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: effectiveDisabled ? null : () => onChanged(!selected),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(
                block.title,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2C3140)),
              ),
              subtitle: Text(
                '단계 ${block.units.length}개 · 탭하면 이 날 계획에 넣거나 빼요',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? Icons.event_available_rounded : Icons.event_outlined,
                    color: selected ? AppChrome.heroAccentBlue : Colors.grey.shade500,
                  ),
                  if (hasMenu || selected) ...[
                    const SizedBox(width: 4),
                    _weekPlanMenu(context, showRemoveFromDay: selected),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekPlanDone(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppChrome.heroCardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(Icons.check_circle_rounded, color: AppChrome.heroAccentBlue, size: 28),
          title: Text(
            block.title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            '단계 ${block.units.length}개',
            style: const TextStyle(fontSize: 13, color: AppChrome.heroMuted),
          ),
          trailing: PopupMenuButton<String>(
            tooltip: '더보기',
            icon: const Icon(Icons.more_vert, color: AppChrome.heroMuted),
            onSelected: (value) {
              if (value == 'delete') onDelete?.call();
              if (value == 'edit') onEditChecklist?.call();
              if (value == 'current') onSetCurrentTask?.call();
              if (value == 'remove_day') onChanged(false);
            },
            itemBuilder: (_) => [
              const PopupMenuItem<String>(
                value: 'remove_day',
                child: Text('이 날 계획에서 빼기'),
              ),
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
              if (onDelete != null)
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('삭제'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandard(BuildContext context, bool effectiveDisabled, bool completed) {
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
