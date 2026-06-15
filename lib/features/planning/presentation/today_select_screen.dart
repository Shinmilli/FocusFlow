import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/layout/desktop_nav_rail.dart';
import '../../../app/layout/responsive_layout.dart';
import '../../../app/theme/app_chrome.dart';
import '../../home/presentation/widgets/home_desktop_side_panel.dart';
import '../domain/task_block.dart';
import '../domain/task_unit.dart';
import 'planning_providers.dart';
import 'widgets/today_pick_tile.dart';
import 'widgets/today_select_header.dart';

class TodaySelectScreen extends ConsumerStatefulWidget {
  const TodaySelectScreen({super.key});

  @override
  ConsumerState<TodaySelectScreen> createState() => _TodaySelectScreenState();
}

class _TodaySelectScreenState extends ConsumerState<TodaySelectScreen> {
  static BoxDecoration _sidePanelDecoration() {
    return BoxDecoration(
      color: AppChrome.pageBackground,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppChrome.softBorder),
    );
  }

  Widget _addBlockButton(BuildContext context, {String? label}) {
    return FilledButton.tonalIcon(
      onPressed: () => context.push('/plan/add'),
      icon: const Icon(Icons.add_rounded),
      label: Text(label ?? '새 블록 추가 (AI로 쪼개기)'),
      style: FilledButton.styleFrom(
        foregroundColor: AppChrome.heroCardDark,
        backgroundColor: const Color(0xFFE8ECF8),
      ),
    );
  }

  List<Widget> _todaySection(
    BuildContext context,
    List<TaskBlock> today,
    Set<String> selected, {
    required bool expanded,
  }) {
    return [
      Text('오늘', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      if (today.isEmpty)
        Text(
          expanded
              ? '오늘 고른 블록이 없어요. 오른쪽 백로그에서 골라요.'
              : '오늘 고른 블록이 없어요. 아래 백로그에서 골라요.',
          style: Theme.of(context).textTheme.bodySmall,
        )
      else
        for (final b in today)
          TodayPickTile(
            block: b.copyWith(isSelectedForToday: true),
            selected: selected.contains(b.id),
            disabled: false,
            maxReached: false,
            onDelete: () => _confirmDeleteBlock(context, ref, b),
            onEditChecklist: () => _editBacklogChecklist(context, ref, b),
            onSetCurrentTask: () => _setCurrentTask(context, ref, b),
            onChanged: (next) => _onPickChanged(
              context,
              ref,
              b,
              selected,
              next,
            ),
          ),
    ];
  }

  List<Widget> _backlogSection(
    BuildContext context,
    List<TaskBlock> backlog,
    Set<String> selected, {
    required bool showTitle,
    required bool addButtonOnRight,
  }) {
    return [
      if (showTitle || addButtonOnRight)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showTitle)
              Expanded(
                child: Text('백로그', style: Theme.of(context).textTheme.titleSmall),
              ),
            if (addButtonOnRight) _addBlockButton(context, label: '새 블록 추가'),
          ],
        ),
      if (showTitle || addButtonOnRight) const SizedBox(height: 8),
      for (final b in backlog)
        TodayPickTile(
          block: b,
          selected: selected.contains(b.id),
          disabled: false,
          maxReached: false,
          onSetCurrentTask: () => _setCurrentTask(context, ref, b),
          onEditChecklist: () => _editBacklogChecklist(context, ref, b),
          onDelete: () => _confirmDeleteBlock(context, ref, b),
          onChanged: (next) => _onPickChanged(
            context,
            ref,
            b,
            selected,
            next,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final asyncToday = ref.watch(todayBlocksProvider);
    final asyncBacklog = ref.watch(backlogBlocksProvider);
    final expanded = ResponsiveLayout.isExpanded(context);

    Widget buildContent(List<TaskBlock> today, List<TaskBlock> backlog) {
      final selected = today.map((b) => b.id).toSet();

      if (expanded) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DesktopNavRail(addButtonSelected: true),
            Expanded(
              flex: 6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 2,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 12, 24),
                      children: [
                        Text(
                          '오늘 선택',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A1C26),
                              ),
                        ),
                        const SizedBox(height: 12),
                        TodaySelectHeader(selectedCount: selected.length),
                        const SizedBox(height: 16),
                        ..._todaySection(context, today, selected, expanded: true),
                        const SizedBox(height: 24),
                        FilledButton(
                          style: AppChrome.primaryActionNavyStyle,
                          onPressed: () => context.pop(),
                          child: const Text('완료'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 280),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 16, 12, 16),
                        child: DecoratedBox(
                          decoration: _sidePanelDecoration(),
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: _backlogSection(
                              context,
                              backlog,
                              selected,
                              showTitle: true,
                              addButtonOnRight: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: HomeDesktopSidePanel.minWidth),
                child: const HomeDesktopSidePanel(),
              ),
            ),
          ],
        );
      }

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TodaySelectHeader(selectedCount: selected.length),
          const SizedBox(height: 12),
          _addBlockButton(context),
          const SizedBox(height: 16),
          ..._todaySection(context, today, selected, expanded: false),
          const SizedBox(height: 16),
          ..._backlogSection(
            context,
            backlog,
            selected,
            showTitle: true,
            addButtonOnRight: false,
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: AppChrome.primaryActionNavyStyle,
            onPressed: () => context.pop(),
            child: const Text('완료'),
          ),
        ],
      );
    }

    final body = asyncToday.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (today) {
        return asyncBacklog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (backlog) => buildContent(today, backlog),
        );
      },
    );

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
              title: const Text('오늘 선택'),
            ),
      body: expanded ? SafeArea(child: body) : body,
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

    await repo.setSelectedForToday(
      todayDateKey(),
      nextSet.toList(),
    );
    if (next) {
      await repo.setCurrentTask(b.id);
    }
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
    ref.invalidate(blocksForDateProvider(todayDateKey()));
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
    final key = todayDateKey();
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
    ref.invalidate(blocksForDateProvider(key));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('블록을 삭제했어요.')),
    );
  }

  Future<void> _setCurrentTask(BuildContext context, WidgetRef ref, TaskBlock block) async {
    final repo = ref.read(planningRepositoryProvider);
    final today = await ref.read(todayBlocksProvider.future);
    final selected = today.map((b) => b.id).toSet();
    if (!selected.contains(block.id)) {
      selected.add(block.id);
      await repo.setSelectedForToday(todayDateKey(), selected.toList());
    }
    await repo.setCurrentTask(block.id);
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
    ref.invalidate(blocksForDateProvider(todayDateKey()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('현재 작업으로 지정했어요.')),
    );
  }

  Future<void> _editBacklogChecklist(BuildContext context, WidgetRef ref, TaskBlock block) async {
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
    await ref.read(planningRepositoryProvider).updateBlock(block.copyWith(units: nextUnits));
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('체크리스트를 수정했어요.')),
    );
  }
}
