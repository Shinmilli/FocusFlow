import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../planning/domain/task_block.dart';
import '../../planning/domain/task_unit.dart';
import '../../planning/presentation/planning_providers.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../data/focus_flow_mcp_bridge.dart';
import '../domain/external_item.dart';
import 'mcp_providers.dart';

enum _McpOrganizeStep { loading, review, organizing, proposal }

/// 외부 항목 가져오기 → AI 정리 → 오늘 선택 → 집중 시작까지 한 흐름.
Future<void> openMcpOrganizeFlow(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetCtx) {
      return _McpOrganizeSheet(hostContext: context);
    },
  );
}

class _McpOrganizeSheet extends ConsumerStatefulWidget {
  const _McpOrganizeSheet({required this.hostContext});

  final BuildContext hostContext;

  @override
  ConsumerState<_McpOrganizeSheet> createState() => _McpOrganizeSheetState();
}

class _McpOrganizeSheetState extends ConsumerState<_McpOrganizeSheet> {
  _McpOrganizeStep _step = _McpOrganizeStep.loading;
  String? _error;
  List<String> _warnings = [];
  List<ExternalItem> _items = [];
  McpOrganizeProposal? _proposal;
  final _selectedBlockIdx = <int>{0};

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _step = _McpOrganizeStep.loading;
      _error = null;
    });
    try {
      final bridge = ref.read(mcpBridgeProvider);
      McpFetchBundle bundle;
      if (bridge is FocusFlowMcpBridge) {
        bundle = await bridge.fetchExternalItemsDetailed();
      } else {
        bundle = McpFetchBundle(items: await bridge.fetchExternalItems());
      }
      if (!mounted) return;
      if (bundle.items.isEmpty) {
        setState(() {
          _warnings = bundle.warnings;
          _error = bundle.warnings.isNotEmpty
              ? bundle.warnings.join('\n')
              : '가져올 항목이 없어요. 외부 도구 연결에서 Google을 연결하거나 기기 캘린더 권한을 허용해 주세요.';
          _items = [];
          _step = _McpOrganizeStep.review;
        });
        return;
      }
      setState(() {
        _items = bundle.items;
        _warnings = bundle.warnings;
        _step = _McpOrganizeStep.review;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _step = _McpOrganizeStep.review;
      });
    }
  }

  Future<void> _organize() async {
    setState(() {
      _step = _McpOrganizeStep.organizing;
      _error = null;
    });

    try {
      final bridge = ref.read(mcpBridgeProvider);
      final life = ref.read(userLifeContextProvider);
      final repo = ref.read(planningRepositoryProvider);
      final dateKey = todayDateKey();
      final today = await repo.loadTodayVisibleBlocks(dateKey);
      final backlog = await repo.loadBacklog();
      final existingTitles = <String>{
        ...today.map((b) => b.title.trim()),
        ...backlog.map((b) => b.title.trim()),
      }.toList();

      final proposal = await bridge.organizeWithAi(
        items: _items,
        lifeContext: life,
        existingTitles: existingTitles,
      );

      if (!mounted) return;
      if (proposal.blocks.isEmpty) {
        setState(() {
          _error = '정리할 블록을 만들지 못했어요. 항목을 다시 확인해 주세요.';
          _step = _McpOrganizeStep.review;
        });
        return;
      }

      setState(() {
        _proposal = proposal;
        _selectedBlockIdx
          ..clear()
          ..add(0);
        if (proposal.blocks.length > 1) _selectedBlockIdx.add(1);
        _step = _McpOrganizeStep.proposal;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _step = _McpOrganizeStep.review;
      });
    }
  }

  Future<void> _applyAndFocus({required bool startFocus}) async {
    final proposal = _proposal;
    if (proposal == null) return;

    final repo = ref.read(planningRepositoryProvider);
    final dateKey = todayDateKey();
    final canAdd = await repo.canAddNewBlock(dateKey);
    if (!canAdd) {
      if (!mounted) return;
      ScaffoldMessenger.of(widget.hostContext).showSnackBar(
        const SnackBar(content: Text('아직 끝나지 않은 블록이 있어요. 완료 후에 적용해요.')),
      );
      return;
    }

    final uuid = const Uuid();
    final todayBlocks = await repo.loadTodayVisibleBlocks(dateKey);
    final backlog = await repo.loadBacklog();
    final existingTitles = <String>{
      ...todayBlocks.map((b) => b.title.trim()),
      ...backlog.map((b) => b.title.trim()),
    };

    final newIds = <String>[];
    String? focusBlockId;

    final sorted = _selectedBlockIdx.toList()..sort();
    for (final i in sorted) {
      if (i < 0 || i >= proposal.blocks.length) continue;
      final b = proposal.blocks[i];
      var title = b.title.trim();
      if (title.isEmpty) continue;
      if (existingTitles.contains(title)) title = '$title (외부)';
      existingTitles.add(title);

      final block = TaskBlock(
        id: uuid.v4(),
        title: title,
        units: [
          for (final u in b.units)
            TaskUnit(
              id: uuid.v4(),
              title: u.trim().isEmpty ? '다음 한 단계' : u,
            ),
        ],
      );
      await repo.addBlock(block);
      newIds.add(block.id);
      focusBlockId ??= block.id;
    }

    final max = 3;
    final nextToday = [...todayBlocks.map((b) => b.id)];
    for (final id in newIds) {
      if (nextToday.length >= max) break;
      if (!nextToday.contains(id)) nextToday.add(id);
    }
    if (nextToday.isNotEmpty) {
      await repo.setSelectedForToday(dateKey, nextToday);
    }

    if (startFocus && focusBlockId != null) {
      await repo.setCurrentTask(focusBlockId);
    }

    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(widget.hostContext).showSnackBar(
      SnackBar(
        content: Text(startFocus ? '적용했어요. 집중 모드로 이동할게요.' : '오늘 블록에 적용했어요.'),
      ),
    );

    if (startFocus) {
      widget.hostContext.push('/focus');
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                '외부 일정 · 할 일 정리',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _StepIndicator(step: _step),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
            _buildActions(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _McpOrganizeStep.loading:
        return const Center(child: CircularProgressIndicator());
      case _McpOrganizeStep.organizing:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('AI가 오늘 집중 블록으로 정리하는 중…', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        );
      case _McpOrganizeStep.review:
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          children: [
            Text(
              'Notion · Google · 삼성(기기) 캘린더에서 가져온 항목이에요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_warnings.isNotEmpty && _items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _warnings.join('\n'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
              ),
            ],
            if (_items.isEmpty) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.hostContext.push('/mcp');
                },
                icon: const Icon(Icons.link),
                label: const Text('외부 도구 연결하기'),
              ),
            ],
            const SizedBox(height: 12),
            if (_items.isEmpty && _error == null)
              const Text('항목이 없어요.')
            else
              for (final item in _items)
                Card(
                  child: ListTile(
                    dense: true,
                    leading: Icon(_iconForSource(item.source)),
                    title: Text(item.title),
                    subtitle: Text(item.sourceLabel),
                  ),
                ),
          ],
        );
      case _McpOrganizeStep.proposal:
        final proposal = _proposal!;
        final remaining = (3 - (ref.watch(todayBlocksProvider).valueOrNull?.length ?? 0)).clamp(0, 3);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          children: [
            Text(proposal.messageForUser, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text('오늘 집중 블록 (최대 $remaining개 선택)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (var i = 0; i < proposal.blocks.length; i++)
              CheckboxListTile(
                value: _selectedBlockIdx.contains(i),
                onChanged: (v) {
                  setState(() {
                    if (v ?? false) {
                      if (_selectedBlockIdx.length < remaining || remaining == 0) {
                        _selectedBlockIdx.add(i);
                      }
                    } else {
                      _selectedBlockIdx.remove(i);
                    }
                  });
                },
                title: Text(proposal.blocks[i].title),
                subtitle: Text(proposal.blocks[i].units.join(' · ')),
                controlAffinity: ListTileControlAffinity.leading,
              ),
          ],
        );
    }
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: switch (_step) {
        _McpOrganizeStep.loading => const SizedBox.shrink(),
        _McpOrganizeStep.review => Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
              const Spacer(),
              if (_items.isNotEmpty)
                FilledButton(
                  onPressed: _organize,
                  child: const Text('AI로 정리하기'),
                ),
            ],
          ),
        _McpOrganizeStep.organizing => const SizedBox.shrink(),
        _McpOrganizeStep.proposal => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _selectedBlockIdx.isEmpty
                    ? null
                    : () => _applyAndFocus(startFocus: true),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('적용하고 집중 시작'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _selectedBlockIdx.isEmpty
                    ? null
                    : () => _applyAndFocus(startFocus: false),
                child: const Text('오늘만 적용'),
              ),
            ],
          ),
      },
    );
  }

  IconData _iconForSource(String source) {
    switch (source) {
      case 'google_calendar':
        return Icons.calendar_month_outlined;
      case 'notion':
        return Icons.note_alt_outlined;
      case 'device_calendar':
        return Icons.phone_android_outlined;
      default:
        return Icons.link;
    }
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final _McpOrganizeStep step;

  @override
  Widget build(BuildContext context) {
    final labels = ['가져오기', '확인', 'AI 정리', '선택'];
    final idx = switch (step) {
      _McpOrganizeStep.loading => 0,
      _McpOrganizeStep.review => 1,
      _McpOrganizeStep.organizing => 2,
      _McpOrganizeStep.proposal => 3,
    };

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= idx
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: i <= idx ? null : Theme.of(context).disabledColor,
                      ),
                ),
              ],
            ),
          ),
          if (i < labels.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
