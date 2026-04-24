import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'goals_providers.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  final _ctrls = <TextEditingController>[];
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(List<String> goals) {
    if (_loaded) return;
    final initial = goals.isEmpty ? <String>[''] : goals;
    for (final g in initial) {
      _ctrls.add(TextEditingController(text: g));
    }
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final list = _ctrls.map((c) => c.text).toList();
      await ref.read(goalsPrefsProvider).save(list);
      ref.invalidate(goalsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장했어요')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addRow() {
    setState(() {
      _ctrls.add(TextEditingController());
    });
  }

  void _removeRow(int i) {
    setState(() {
      _ctrls[i].dispose();
      _ctrls.removeAt(i);
      if (_ctrls.isEmpty) {
        _ctrls.add(TextEditingController());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncGoals = ref.watch(goalsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('목표'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '저장 중…' : '저장'),
          ),
        ],
      ),
      body: asyncGoals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (goals) {
          _ensureControllers(goals);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '목표는 3개 이상 입력해도 돼요. 여기에 적은 내용은 AI 제안/계획에 힌트로 사용돼요.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _ctrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrls[i],
                          decoration: InputDecoration(
                            labelText: '목표 ${i + 1}',
                            border: const OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) {
                            if (i == _ctrls.length - 1) _addRow();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: '삭제',
                        onPressed: () => _removeRow(i),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add),
                label: const Text('목표 추가'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
  }
}

