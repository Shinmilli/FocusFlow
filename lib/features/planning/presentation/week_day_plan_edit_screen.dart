import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/app_chrome.dart';
import '../domain/task_block.dart';
import '../domain/task_unit.dart';
import 'planning_providers.dart';
import 'widgets/today_pick_tile.dart';

/// 이번 주 조정 → 편집: 해당 날짜의 백로그·계획 토글·새 블록·완료.
class WeekDayPlanEditScreen extends ConsumerWidget {
  const WeekDayPlanEditScreen({
    super.key,
    required this.dateKey,
    this.embedded = false,
  });

  final String dateKey;
  final bool embedded;

  static DateTime _parseDateKey(String k) {
    try {
      final p = k.split('-');
      if (p.length != 3) return DateTime.now();
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) {
      return DateTime.now();
    }
  }

  static DateTime _startOfWeek(DateTime d) {
    final delta = (d.weekday - DateTime.monday) % 7;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: delta));
  }

  static String _dateKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static void _invalidateWeekAround(WidgetRef ref, String key) {
    final d = _parseDateKey(key);
    final start = _startOfWeek(d);
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
  Widget build(BuildContext context, WidgetRef ref) {
    final d = _parseDateKey(dateKey);
    final asyncPlan = ref.watch(blocksForDateProvider(dateKey));
    final asyncBacklog = ref.watch(backlogForDateProvider(dateKey));

    Widget buildContent(List<TaskBlock> planBlocks, List<TaskBlock> backlog) {
      final selected = planBlocks.map((b) => b.id).toSet();
      final todos = planBlocks.where((b) => !b.isFullyComplete).toList();
      final dones = planBlocks.where((b) => b.isFullyComplete).toList();

      return ListView(
        padding: EdgeInsets.fromLTRB(16, embedded ? 8 : 8, 16, 24),
        children: [
          Text(
            '백로그에서 탭하면 이 날 계획에 넣거나, 계획에서 빼요. 새 블록은 아래에서 추가할 수 있어요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5C6378),
                ),
          ),
          const SizedBox(height: 16),
          Text(
            '이 날 계획 · 끝낸 리스트',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C3140),
                ),
          ),
          const SizedBox(height: 8),
          if (dones.isEmpty)
            Text(
              '없음',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
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
                onEditChecklist: () => _editBacklogChecklist(context, ref, dateKey, b),
                onMoveToTodoList: () => _moveToTodoList(context, ref, dateKey, b),
                onChanged: (next) => _onPickChanged(context, ref, b, selected, next),
              ),
          const SizedBox(height: 16),
          Text(
            '이 날 계획 · 할 리스트',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C3140),
                ),
          ),
          const SizedBox(height: 8),
          if (todos.isEmpty)
            Text(
              '없음',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
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
                onEditChecklist: () => _editBacklogChecklist(context, ref, dateKey, b),
                onMoveToDoneList: () => _moveToDoneList(context, ref, dateKey, b),
                onChanged: (next) => _onPickChanged(context, ref, b, selected, next),
              ),
          const SizedBox(height: 20),
          Divider(height: 1, color: AppChrome.softBorder.withValues(alpha: 0.9)),
          const SizedBox(height: 16),
          Text(
            '백로그',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C3140),
                ),
          ),
          const SizedBox(height: 8),
          if (backlog.isEmpty)
            Text(
              '백로그가 비었어요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            )
          else
            for (final b in backlog)
              TodayPickTile(
                block: b,
                selected: selected.contains(b.id),
                disabled: false,
                maxReached: false,
                variant: TodayPickTileVariant.weekPlan,
                onEditChecklist: () => _editBacklogChecklist(context, ref, dateKey, b),
                onDelete: () => _confirmDeleteBlock(context, ref, b),
                onChanged: (next) => _onPickChanged(context, ref, b, selected, next),
              ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/plan/add'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('새 블록 추가'),
            style: FilledButton.styleFrom(
              foregroundColor: AppChrome.heroCardDark,
              backgroundColor: const Color(0xFFE8ECF8),
            ),
          ),
          if (!embedded) ...[
            const SizedBox(height: 12),
            FilledButton(
              style: AppChrome.primaryActionNavyStyle,
              onPressed: () => context.pop(),
              child: const Text('완료'),
            ),
          ],
        ],
      );
    }

    final body = asyncPlan.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (planBlocks) {
        return asyncBacklog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (backlog) => buildContent(planBlocks, backlog),
        );
      },
    );

    if (embedded) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppChrome.pageBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppChrome.softBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Text(
                  '${d.month}/${d.day} · 이 날짜 계획 편집',
                  style: const TextStyle(
                    color: AppChrome.navPrimaryBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppChrome.pageBackground,
      appBar: AppBar(
        backgroundColor: AppChrome.topBarBackground,
        foregroundColor: AppChrome.topBarForeground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text('${d.month}/${d.day} 계획 편집'),
      ),
      body: body,
    );
  }

  Future<void> _onPickChanged(
    BuildContext context,
    WidgetRef ref,
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
    _invalidateWeekAround(ref, dateKey);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('블록을 삭제했어요.')),
    );
  }

  Future<void> _moveToDoneList(BuildContext context, WidgetRef ref, String dateKey, TaskBlock block) async {
    await ref.read(planningRepositoryProvider).setPlanBlockFullyCompleteForDate(dateKey, block.id, true);
    _invalidateWeekAround(ref, dateKey);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('끝낸 리스트로 옮겼어요.')),
    );
  }

  Future<void> _moveToTodoList(BuildContext context, WidgetRef ref, String dateKey, TaskBlock block) async {
    await ref.read(planningRepositoryProvider).setPlanBlockFullyCompleteForDate(dateKey, block.id, false);
    _invalidateWeekAround(ref, dateKey);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('할 리스트로 옮겼어요.')),
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
    ref.invalidate(blocksForDateProvider(dateKey));
    ref.invalidate(backlogForDateProvider(dateKey));
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('체크리스트를 수정했어요.')),
    );
  }
}
