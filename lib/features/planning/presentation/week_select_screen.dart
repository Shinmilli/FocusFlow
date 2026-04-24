import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/focus_flow_limits.dart';
import '../domain/task_block.dart';
import 'planning_providers.dart';
import 'widgets/today_pick_tile.dart';
import 'widgets/today_select_header.dart';

class WeekSelectScreen extends ConsumerStatefulWidget {
  const WeekSelectScreen({super.key});

  @override
  ConsumerState<WeekSelectScreen> createState() => _WeekSelectScreenState();
}

class _WeekSelectScreenState extends ConsumerState<WeekSelectScreen> {
  static const _initialBacklogVisible = 4;
  int _backlogVisible = _initialBacklogVisible;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _today();
  }

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _dateKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  DateTime _startOfWeek(DateTime d) {
    // Monday-start week.
    final delta = (d.weekday - DateTime.monday) % 7;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: delta));
  }

  @override
  Widget build(BuildContext context) {
    final start = _startOfWeek(_selectedDay);
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    final selectedKey = _dateKey(_selectedDay);
    final isToday = selectedKey == todayDateKey();

    final asyncSelectedBlocks = ref.watch(blocksForDateProvider(selectedKey));
    final asyncBacklog = ref.watch(backlogBlocksProvider);
    final asyncCanAddToday = ref.watch(canAddNewBlockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('이번 주 조정'),
      ),
      body: asyncCanAddToday.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (canAddToday) {
          // Selecting future days should be allowed even if today can't add new blocks.
          final canChangeSelection = isToday ? canAddToday : true;

          return asyncSelectedBlocks.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (selectedBlocks) {
              return asyncBacklog.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (backlog) {
                  final selected = selectedBlocks.map((b) => b.id).toSet();
                  final visibleBacklog = backlog.length <= _backlogVisible
                      ? backlog
                      : backlog.sublist(0, _backlogVisible);
                  final hidden = backlog.length - visibleBacklog.length;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '일주일 단위로 “오늘 3개”를 조정해요.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      _WeekStrip(
                        days: days,
                        selected: _selectedDay,
                        onSelect: (d) => setState(() => _selectedDay = d),
                      ),
                      const SizedBox(height: 12),
                      if (!isToday)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '지금은 ${_selectedDay.month}/${_selectedDay.day}을(를) 편집 중이에요. '
                              '선택은 자유롭게 바꿀 수 있어요.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      if (!isToday) const SizedBox(height: 12),
                      TodaySelectHeader(
                        selectedCount: selected.length,
                        canAdd: canChangeSelection,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: canAddToday ? () => context.push('/plan/add') : null,
                        icon: const Icon(Icons.add),
                        label: const Text('새 블록 추가 (AI로 쪼개기)'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${_selectedDay.month}/${_selectedDay.day}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      if (selectedBlocks.isEmpty)
                        Text(
                          '선택된 블록이 없어요. 아래 백로그에서 골라요.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else
                        for (final b in selectedBlocks)
                          TodayPickTile(
                            block: b.copyWith(isSelectedForToday: isToday),
                            selected: selected.contains(b.id),
                            disabled: !canChangeSelection && !selected.contains(b.id),
                            maxReached: selected.length >= FocusFlowLimits.maxSelectableBlocksPerDay,
                            onChanged: (next) => _onPickChanged(
                              context,
                              ref,
                              selectedKey,
                              b,
                              selected,
                              canChangeSelection,
                              next,
                            ),
                          ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('백로그', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(width: 8),
                          Text(
                            '(${backlog.length}개)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final b in visibleBacklog)
                        TodayPickTile(
                          block: b,
                          selected: selected.contains(b.id),
                          disabled: !canChangeSelection && !selected.contains(b.id),
                          maxReached: selected.length >= FocusFlowLimits.maxSelectableBlocksPerDay,
                          onChanged: (next) => _onPickChanged(
                            context,
                            ref,
                            selectedKey,
                            b,
                            selected,
                            canChangeSelection,
                            next,
                          ),
                        ),
                      if (hidden > 0)
                        TextButton(
                          onPressed: () => setState(() => _backlogVisible = backlog.length),
                          child: Text('백로그 더 보기 (+$hidden)'),
                        )
                      else if (backlog.length > _initialBacklogVisible)
                        TextButton(
                          onPressed: () => setState(() => _backlogVisible = _initialBacklogVisible),
                          child: const Text('백로그 접기'),
                        ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.pop(),
                        child: const Text('완료'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onPickChanged(
    BuildContext context,
    WidgetRef ref,
    String dateKey,
    TaskBlock b,
    Set<String> selected,
    bool canChangeSelection,
    bool next,
  ) async {
    final repo = ref.read(planningRepositoryProvider);
    final nextSet = {...selected};

    if (!canChangeSelection && next && !selected.contains(b.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 블록이 완료될 때까지는 다음 일을 추가하지 않아요.')),
      );
      return;
    }

    if (next) {
      if (selected.length >= FocusFlowLimits.maxSelectableBlocksPerDay) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('하루 최대 ${FocusFlowLimits.maxSelectableBlocksPerDay}개만 선택할 수 있어요.'),
          ),
        );
        return;
      }
      nextSet.add(b.id);
    } else {
      nextSet.remove(b.id);
    }

    await repo.setSelectedForToday(dateKey, nextSet.toList());

    // Invalidate both "today" and the selected date providers.
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(blocksForDateProvider(dateKey));
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final isSelected = d.year == selected.year && d.month == selected.month && d.day == selected.day;
          final label = '${_weekdayShort(d.weekday)} ${d.day}';
          return ChoiceChip(
            selected: isSelected,
            label: Text(label),
            onSelected: (_) => onSelect(d),
          );
        },
      ),
    );
  }

  String _weekdayShort(int weekday) {
    return switch (weekday) {
      DateTime.monday => '월',
      DateTime.tuesday => '화',
      DateTime.wednesday => '수',
      DateTime.thursday => '목',
      DateTime.friday => '금',
      DateTime.saturday => '토',
      DateTime.sunday => '일',
      _ => '',
    };
  }
}

