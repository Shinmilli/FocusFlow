import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/layout/desktop_nav_rail.dart';
import '../../../app/layout/responsive_layout.dart';
import '../../../app/theme/app_chrome.dart';
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
  final _unitCtrls = <TextEditingController>[];

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final c in _unitCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _setUnits(List<String> titles) {
    for (final c in _unitCtrls) {
      c.dispose();
    }
    _unitCtrls
      ..clear()
      ..addAll(
        (titles.isEmpty ? <String>['준비 60초', '핵심 10분', '마무리 3분'] : titles.take(4))
            .map((t) => TextEditingController(text: t)),
      );
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
        _setUnits(units.map((u) => u.title).take(4).toList());
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _addUnit() {
    if (_unitCtrls.length >= 4) return;
    setState(() {
      _unitCtrls.add(TextEditingController());
    });
  }

  void _removeUnit(int i) {
    setState(() {
      _unitCtrls[i].dispose();
      _unitCtrls.removeAt(i);
      if (_unitCtrls.isEmpty) {
        _unitCtrls.add(TextEditingController(text: '준비 60초'));
      }
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final repo = ref.read(planningRepositoryProvider);
    final uuid = const Uuid();
    final raw = _unitCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).take(4).toList();
    final unitTitles = raw.isEmpty ? ['준비 60초', '핵심 10분', '마무리 3분'] : raw;
    final units = [
      for (final t in unitTitles) TaskUnit(id: uuid.v4(), title: t, isDone: false),
    ];

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

  Widget _introCard(BuildContext context, {required bool expanded}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          expanded
              ? '큰 일을 적으면 AI가 “시작 가능한 체크리스트(최대 4개)”로 쪼개요. '
                  '마음에 안 들면 오른쪽에서 직접 수정해도 돼요.'
              : '큰 일을 적으면 AI가 “시작 가능한 체크리스트(최대 4개)”로 쪼개요. '
                  '마음에 안 들면 아래에서 직접 수정해도 돼요.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _titleField() {
    return TextField(
      controller: _titleCtrl,
      enabled: !_loading,
      decoration: const InputDecoration(
        labelText: '큰 일 (예: 과제 제출)',
        border: OutlineInputBorder(),
      ),
      onSubmitted: (_) => _runDecompose(),
    );
  }

  Widget _aiButton() {
    return FilledButton.icon(
      onPressed: _loading ? null : _runDecompose,
      icon: const Icon(Icons.auto_awesome),
      label: Text(_loading ? '분해 중...' : 'AI로 작은 단계 만들기'),
    );
  }

  Widget _saveButton() {
    return FilledButton(
      style: AppChrome.primaryActionNavyStyle,
      onPressed: _loading ? null : _save,
      child: const Text('백로그에 저장'),
    );
  }

  Widget _checklistSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('체크리스트', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 8),
            Text(
              '(최대 4개)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: (_unitCtrls.length >= 4 || _loading) ? null : _addUnit,
              icon: const Icon(Icons.add),
              label: const Text('추가'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_unitCtrls.isEmpty)
          Text(
            '먼저 AI로 생성하거나 직접 추가해 주세요.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          for (var i = 0; i < _unitCtrls.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _unitCtrls[i],
                      enabled: !_loading,
                      decoration: InputDecoration(
                        labelText: '단계 ${i + 1}',
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        if (i == _unitCtrls.length - 1) _addUnit();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '삭제',
                    onPressed: _loading ? null : () => _removeUnit(i),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _leftColumn(BuildContext context, {required bool expanded}) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, expanded ? 16 : 0, expanded ? 12 : 0, 24),
      children: [
        if (expanded)
          Text(
            '새 블록 추가',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1C26),
                ),
          ),
        if (expanded) const SizedBox(height: 12),
        _introCard(context, expanded: expanded),
        const SizedBox(height: 12),
        _titleField(),
        const SizedBox(height: 12),
        _aiButton(),
        const SizedBox(height: 24),
        _saveButton(),
      ],
    );
  }

  static BoxDecoration _checklistPanelDecoration() {
    return BoxDecoration(
      color: AppChrome.pageBackground,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppChrome.softBorder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expanded = ResponsiveLayout.isExpanded(context);

    final body = expanded
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DesktopNavRail(),
              Expanded(
                flex: 2,
                child: _leftColumn(context, expanded: true),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: DecoratedBox(
                    decoration: _checklistPanelDecoration(),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _checklistSection(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _introCard(context, expanded: expanded),
              const SizedBox(height: 12),
              _titleField(),
              const SizedBox(height: 12),
              _aiButton(),
              const SizedBox(height: 12),
              _checklistSection(context),
              const SizedBox(height: 4),
              _saveButton(),
            ],
          );

    return Scaffold(
      backgroundColor: AppChrome.pageBackground,
      appBar: expanded
          ? null
          : AppBar(
              backgroundColor: AppChrome.topBarBackground,
              foregroundColor: AppChrome.topBarForeground,
              surfaceTintColor: Colors.transparent,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              title: const Text('새 블록 추가'),
            ),
      body: expanded ? SafeArea(child: body) : body,
    );
  }
}

