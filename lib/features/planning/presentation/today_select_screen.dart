import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/task_block.dart';
import 'planning_providers.dart';
import 'widgets/today_pick_tile.dart';
import 'widgets/today_select_header.dart';

class TodaySelectScreen extends ConsumerStatefulWidget {
  const TodaySelectScreen({super.key});

  @override
  ConsumerState<TodaySelectScreen> createState() => _TodaySelectScreenState();
}

class _TodaySelectScreenState extends ConsumerState<TodaySelectScreen> {
  static const _initialBacklogVisible = 3;
  int _backlogVisible = _initialBacklogVisible;

  @override
  Widget build(BuildContext context) {
    final asyncToday = ref.watch(todayBlocksProvider);
    final asyncBacklog = ref.watch(backlogBlocksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘 선택'),
      ),
      body: asyncToday.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (today) {
          return asyncBacklog.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (backlog) {
                  final selected = today.map((b) => b.id).toSet();
                  final visibleBacklog = backlog.length <= _backlogVisible
                      ? backlog
                      : backlog.sublist(0, _backlogVisible);
                  final hidden = backlog.length - visibleBacklog.length;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TodaySelectHeader(
                        selectedCount: selected.length,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () => context.push('/plan/add'),
                        icon: const Icon(Icons.add),
                        label: const Text('새 블록 추가 (AI로 쪼개기)'),
                      ),
                      const SizedBox(height: 16),
                      Text('오늘', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      if (today.isEmpty)
                        Text(
                          '오늘 고른 블록이 없어요. 아래 백로그에서 골라요.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else
                        for (final b in today)
                          TodayPickTile(
                            block: b.copyWith(isSelectedForToday: true),
                            selected: selected.contains(b.id),
                            disabled: false,
                            maxReached: false,
                            onChanged: (next) => _onPickChanged(
                              context,
                              ref,
                              b,
                              selected,
                              next,
                            ),
                          ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('백로그', style: Theme.of(context).textTheme.titleSmall),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '한 번에 다 보이지 않게 접어 두었어요. 필요할 때만 더 펼쳐요.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      for (final b in visibleBacklog)
                        TodayPickTile(
                          block: b,
                          selected: selected.contains(b.id),
                          disabled: false,
                          maxReached: false,
                          onDelete: () => _confirmDeleteBacklog(context, ref, b),
                          onChanged: (next) => _onPickChanged(
                            context,
                            ref,
                            b,
                            selected,
                            next,
                          ),
                        ),
                      if (hidden > 0)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _backlogVisible = backlog.length;
                            });
                          },
                          child: Text('백로그 더 보기 (+$hidden)'),
                        )
                      else if (backlog.length > _initialBacklogVisible)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _backlogVisible = _initialBacklogVisible;
                            });
                          },
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
      ),
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
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
  }

  Future<void> _confirmDeleteBacklog(BuildContext context, WidgetRef ref, TaskBlock block) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('백로그 삭제'),
        content: Text('`${block.title}` 블록을 삭제할까요?'),
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
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('백로그 블록을 삭제했어요.')),
    );
  }
}
