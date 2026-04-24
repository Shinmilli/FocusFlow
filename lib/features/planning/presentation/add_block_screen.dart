import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../ai_agent/presentation/ai_providers.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../domain/task_block.dart';
import '../domain/task_unit.dart';
import 'planning_providers.dart';

class AddBlockScreen extends ConsumerStatefulWidget {
  const AddBlockScreen({super.key});

  @override
  ConsumerState<AddBlockScreen> createState() => _AddBlockScreenState();
}

class _AddBlockScreenState extends ConsumerState<AddBlockScreen> {
  final _titleCtrl = TextEditingController();
  bool _loading = false;
  List<TaskUnit> _units = const [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _runDecompose() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _loading = true;
    });
    try {
      final ctx = ref.read(userLifeContextProvider);
      final agent = ref.read(aiAgentServiceProvider);
      final units = await agent.decomposeTask(taskTitle: title, context: ctx);
      if (!mounted) return;
      setState(() {
        _units = units.isEmpty
            ? [TaskUnit(id: 'u1', title: '준비 2분'), TaskUnit(id: 'u2', title: '핵심만 10분')]
            : units;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final repo = ref.read(planningRepositoryProvider);
    final uuid = const Uuid();
    final units = _units.isEmpty
        ? [
            TaskUnit(id: uuid.v4(), title: '준비 2분'),
            TaskUnit(id: uuid.v4(), title: '핵심만 10분'),
            TaskUnit(id: uuid.v4(), title: '마무리 3분'),
          ]
        : _units
            .map(
              (u) => TaskUnit(
                id: u.id.startsWith('u-') ? uuid.v4() : u.id,
                title: u.title,
                isDone: u.isDone,
              ),
            )
            .toList();

    await repo.addBlock(
      TaskBlock(
        id: uuid.v4(),
        title: title,
        units: units,
      ),
    );

    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('백로그에 추가했어요')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final asyncCanAdd = ref.watch(canAddNewBlockProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('새 블록 추가')),
      body: asyncCanAdd.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (canAdd) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    canAdd
                        ? '큰 일을 적으면 AI가 바로 “시작 가능한 단계”로 쪼개요.'
                        : '아직 끝나지 않은 블록이 있어요. 과부하 방지를 위해 완료 전에는 새 블록을 추가하지 않아요.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                enabled: canAdd && !_loading,
                decoration: const InputDecoration(
                  labelText: '큰 일 (예: 과제 제출)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _runDecompose(),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: (canAdd && !_loading) ? _runDecompose : null,
                icon: const Icon(Icons.auto_awesome),
                label: Text(_loading ? '분해 중...' : 'AI로 작은 단계 만들기'),
              ),
              const SizedBox(height: 12),
              if (_units.isNotEmpty) ...[
                Text('생성된 단계', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final u in _units)
                  ListTile(
                    leading: const Icon(Icons.check_box_outline_blank),
                    title: Text(u.title),
                  ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: canAdd && !_loading ? _save : null,
                child: const Text('백로그에 저장'),
              ),
            ],
          );
        },
      ),
    );
  }
}

