import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/layout/responsive_layout.dart';
import '../../../app/theme/app_chrome.dart';
import '../domain/task_block.dart';
import '../domain/task_unit.dart';
import 'planning_providers.dart';
import 'week_day_plan_edit_screen.dart';
import 'widgets/today_pick_tile.dart';

class WeekSelectScreen extends ConsumerStatefulWidget {
  const WeekSelectScreen({super.key});

  @override
  ConsumerState<WeekSelectScreen> createState() => _WeekSelectScreenState();
}

class _WeekSelectScreenState extends ConsumerState<WeekSelectScreen> {
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
    final delta = (d.weekday - DateTime.monday) % 7;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: delta));
  }

  void _invalidateWeekAround(WidgetRef ref, DateTime anchor) {
    final start = _startOfWeek(anchor);
    for (var i = 0; i < 7; i++) {
      final k = _dateKey(start.add(Duration(days: i)));
      ref.invalidate(blocksForDateProvider(k));
      ref.invalidate(backlogForDateProvider(k));
    }
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
  }

  @override
  Widget build(BuildContext context) {
    final start = _startOfWeek(_selectedDay);
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    final selectedKey = _dateKey(_selectedDay);
    final isToday = selectedKey == todayDateKey();

    final asyncSelectedBlocks = ref.watch(blocksForDateProvider(selectedKey));

    final shell = StatefulNavigationShell.maybeOf(context);
    final expanded = ResponsiveLayout.isExpanded(context);

    Widget buildPlanList(List<TaskBlock> selectedBlocks) {
      final selected = selectedBlocks.map((b) => b.id).toSet();
      final todos = selectedBlocks.where((b) => !b.isFullyComplete).toList();
      final dones = selectedBlocks.where((b) => b.isFullyComplete).toList();

      return ListView(
        padding: EdgeInsets.fromLTRB(16, expanded ? 16 : 0, 16, 24),
        children: [
          if (expanded)
            Text(
              '이번 주 조정',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1C26),
                  ),
            ),
          if (expanded) const SizedBox(height: 8),
          Text(
            '일주일 단위로 날짜별 계획을 조정해요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5C6378),
                ),
          ),
          const SizedBox(height: 12),
          _WeekStrip(
            days: days,
            selected: _selectedDay,
            onSelect: (d) => setState(() => _selectedDay = d),
          ),
          const SizedBox(height: 16),
          if (!isToday)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppChrome.softCardDecoration(),
              child: Text(
                '지금은 ${_selectedDay.month}/${_selectedDay.day} 계획을 보고 있어요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5C6378),
                    ),
              ),
            ),
          if (!isToday) const SizedBox(height: 16),
          Text(
            'Plan list',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5C6378),
                  letterSpacing: 0.4,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '끝낸 리스트 · ${dones.length}개',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C3140),
                ),
          ),
          const SizedBox(height: 8),
          if (dones.isEmpty)
            Text(
              '이 날짜에 완료된 블록이 없어요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            )
          else
            for (final b in dones)
              TodayPickTile(
                block: b,
                selected: selected.contains(b.id),
                disabled: false,
                maxReached: false,
                variant: TodayPickTileVariant.weekPlan,
                onDelete: () => _confirmDeleteBlock(context, ref, b),
                onEditChecklist: () => _editBacklogChecklist(context, ref, selectedKey, b),
                onMoveToTodoList: () => _moveToTodoList(context, ref, selectedKey, b),
                onChanged: (next) => _onPickChanged(
                  context,
                  ref,
                  selectedKey,
                  b,
                  selected,
                  next,
                ),
              ),
          const SizedBox(height: 20),
          Text(
            '할 리스트 · ${todos.length}개',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C3140),
                ),
          ),
          const SizedBox(height: 8),
          if (todos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                expanded
                    ? '아직 넣은 블록이 없어요. 오른쪽에서 백로그·새 블록으로 채울 수 있어요.'
                    : '아직 넣은 블록이 없어요. 편집에서 백로그·새 블록으로 채울 수 있어요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            )
          else
            for (final b in todos)
              TodayPickTile(
                block: b,
                selected: selected.contains(b.id),
                disabled: false,
                maxReached: false,
                variant: TodayPickTileVariant.weekPlan,
                onDelete: () => _confirmDeleteBlock(context, ref, b),
                onEditChecklist: () => _editBacklogChecklist(context, ref, selectedKey, b),
                onMoveToDoneList: () => _moveToDoneList(context, ref, selectedKey, b),
                onChanged: (next) => _onPickChanged(
                  context,
                  ref,
                  selectedKey,
                  b,
                  selected,
                  next,
                ),
              ),
          if (!expanded) ...[
            const SizedBox(height: 24),
            Text(
              '편집',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5C6378),
                    letterSpacing: 0.3,
                  ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: AppChrome.softCardDecoration(),
              child: FilledButton.tonalIcon(
                onPressed: () => context.push(
                  '/plan/week/edit?date=${Uri.encodeQueryComponent(selectedKey)}',
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('이 날짜 계획 편집'),
                style: FilledButton.styleFrom(
                  foregroundColor: AppChrome.heroCardDark,
                  backgroundColor: const Color(0xFFE8ECF8),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
            ),
          ],
        ],
      );
    }

    final content = asyncSelectedBlocks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: buildPlanList,
    );

    final body = expanded
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 420,
                child: content,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: WeekDayPlanEditScreen(
                    key: ValueKey(selectedKey),
                    dateKey: selectedKey,
                    embedded: true,
                  ),
                ),
              ),
            ],
          )
        : content;

    return Scaffold(
      backgroundColor: AppChrome.pageBackground,
      appBar: expanded
          ? null
          : AppBar(
        backgroundColor: AppChrome.topBarBackground,
        foregroundColor: AppChrome.topBarForeground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text('이번 주 조정'),
        leading: shell != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                tooltip: '오늘',
                onPressed: () => shell.goBranch(0),
              )
            : null,
        automaticallyImplyLeading: shell == null,
      ),
      body: expanded ? SafeArea(child: body) : body,
    );
  }

  Future<void> _onPickChanged(
    BuildContext context,
    WidgetRef ref,
    String dateKey,
    TaskBlock b,
    Set<String> selected,
    bool next,
  ) async {
    final repo = ref.read(planningRepositoryProvider);
    final nextSet = {...selected};

    if (next) {
      nextSet.add(b.id);
    } else {
      nextSet.remove(b.id);
    }

    await repo.setSelectedForToday(dateKey, nextSet.toList());

    ref.invalidate(todayBlocksProvider);
    ref.invalidate(blocksForDateProvider(dateKey));
    ref.invalidate(backlogForDateProvider(dateKey));
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
  }

  Future<void> _moveToDoneList(BuildContext context, WidgetRef ref, String dateKey, TaskBlock block) async {
    await ref.read(planningRepositoryProvider).setPlanBlockFullyCompleteForDate(dateKey, block.id, true);
    _invalidateWeekAround(ref, _selectedDay);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('끝낸 리스트로 옮겼어요.')),
    );
  }

  Future<void> _moveToTodoList(BuildContext context, WidgetRef ref, String dateKey, TaskBlock block) async {
    await ref.read(planningRepositoryProvider).setPlanBlockFullyCompleteForDate(dateKey, block.id, false);
    _invalidateWeekAround(ref, _selectedDay);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('할 리스트로 옮겼어요.')),
    );
  }

  Future<void> _confirmDeleteBlock(BuildContext context, WidgetRef ref, TaskBlock block) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('블록 삭제'),
        content: Text(
          '`${block.title}` 블록을 완전히 삭제할까요?\n'
          '오늘·백로그·다른 날짜 선택에서도 모두 사라져요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    await ref.read(planningRepositoryProvider).deleteBlock(block.id);
    _invalidateWeekAround(ref, _selectedDay);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('블록을 삭제했어요.')),
    );
  }

  Future<void> _editBacklogChecklist(BuildContext context, WidgetRef ref, String dateKey, TaskBlock block) async {
    final controllers = block.units
        .take(4)
        .map((u) => TextEditingController(text: u.title))
        .toList();
    if (controllers.isEmpty) {
      controllers.add(TextEditingController(text: '준비 60초'));
    }
    final uuid = const Uuid();
    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('체크리스트 수정', style: Theme.of(sheetContext).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (var i = 0; i < controllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controllers[i],
                              decoration: InputDecoration(
                                labelText: '단계 ${i + 1}',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: controllers.length <= 1
                                ? null
                                : () {
                                    setSheetState(() {
                                      controllers[i].dispose();
                                      controllers.removeAt(i);
                                    });
                                  },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: controllers.length >= 4
                          ? null
                          : () {
                              setSheetState(() {
                                controllers.add(TextEditingController());
                              });
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('단계 추가'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    style: AppChrome.primaryActionNavyStyle,
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: const Text('저장'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      for (final c in controllers) {
        c.dispose();
      }
      return;
    }

    final raw = controllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    for (final c in controllers) {
      c.dispose();
    }
    if (raw.isEmpty) return;

    final nextUnits = <TaskUnit>[];
    for (var i = 0; i < raw.length && i < 4; i++) {
      if (i < block.units.length) {
        nextUnits.add(block.units[i].copyWith(title: raw[i]));
      } else {
        nextUnits.add(TaskUnit(id: uuid.v4(), title: raw[i]));
      }
    }
    await ref.read(planningRepositoryProvider).upsertPlanBlockForDate(dateKey, block.copyWith(units: nextUnits));
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(blocksForDateProvider(_dateKey(_selectedDay)));
    ref.invalidate(backlogForDateProvider(_dateKey(_selectedDay)));
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('체크리스트를 수정했어요.')),
    );
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppChrome.softCardDecoration(),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final d = days[i];
            final isSelected =
                d.year == selected.year && d.month == selected.month && d.day == selected.day;
            final label = '${_weekdayShort(d.weekday)} ${d.day}';
            return FilterChip(
              selected: isSelected,
              showCheckmark: false,
              label: Text(label),
              selectedColor: AppChrome.heroAccentBlue.withValues(alpha: 0.22),
              side: const BorderSide(color: AppChrome.softBorder),
              onSelected: (_) => onSelect(d),
            );
          },
        ),
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
