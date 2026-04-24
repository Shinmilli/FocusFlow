import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/focus_flow_limits.dart';
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
    final asyncCanAdd = ref.watch(canAddNewBlockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘 3개 선택'),
      ),
      body: asyncCanAdd.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (canAdd) {
          return asyncToday.when(
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
                        canAdd: canAdd,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: canAdd ? () => context.push('/plan/add') : null,
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
                            disabled: !canAdd && !selected.contains(b.id),
                            maxReached:
                                selected.length >= FocusFlowLimits.maxSelectableBlocksPerDay,
                            onChanged: (next) => _onPickChanged(
                              context,
                              ref,
                              b,
                              selected,
                              canAdd,
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
                          disabled: !canAdd && !selected.contains(b.id),
                          maxReached:
                              selected.length >= FocusFlowLimits.maxSelectableBlocksPerDay,
                          onChanged: (next) => _onPickChanged(
                            context,
                            ref,
                            b,
                            selected,
                            canAdd,
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
    bool canAdd,
    bool next,
  ) async {
    final repo = ref.read(planningRepositoryProvider);
    final nextSet = {...selected};

    if (!canAdd && next && !selected.contains(b.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현재 블록이 완료될 때까지는 다음 일을 추가하지 않아요.'),
        ),
      );
      return;
    }

    if (next) {
      if (selected.length >= FocusFlowLimits.maxSelectableBlocksPerDay) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '하루 최대 ${FocusFlowLimits.maxSelectableBlocksPerDay}개만 선택할 수 있어요.',
            ),
          ),
        );
        return;
      }
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
}
