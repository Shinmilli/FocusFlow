import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_chrome.dart';
import '../../ai_agent/presentation/ai_providers.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../../planning/presentation/planning_providers.dart';
import '../../planning/domain/task_block.dart';
import '../domain/focus_log_event.dart';
import 'focus_log_providers.dart';
import 'widgets/leave_hint_card.dart';
import 'widgets/parked_thoughts_card.dart';
import 'widgets/time_flow_ring.dart';

/// Time Flow UI 골격, 카운트다운, 5분 모드, 딴생각→AI 유도.
/// 앱 이탈 감지: [WidgetsBindingObserver].
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with WidgetsBindingObserver {
  static const int _breakDurationSec = 5 * 60;

  Timer? _timer;
  int _remainingSec = 50 * 60;
  int _sessionTotalSec = 50 * 60;
  int _selectedMinutes = 50;
  int _countdown = 0;
  bool _running = false;
  /// 집중 타이머는 유지한 채 링만 멈추고, 안쪽에서만 5분 휴식이 카운트다운.
  bool _onBreak = false;
  int _breakRemainingSec = _breakDurationSec;
  double _frozenRingProgress = 0;
  String? _leaveHint;
  int? _lastAttemptTs;
  /// 과제용 자료 찾기 등 — 이탈이 아님을 스스로 표시.
  bool _taskLookupNotLeave = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      setState(() {
        _leaveHint = '잠깐 이탈했어요. 다시 한 번 호흡하고 같은 화면으로 돌아왔어요.';
      });
      ref.read(focusLogRepositoryProvider).append(
            FocusLogEvent(
              type: FocusLogEventType.distraction,
              tsMs: DateTime.now().millisecondsSinceEpoch,
              dateKey: _todayKey(),
              meta: {'lifecycle': state.name},
            ),
          );
    }
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  void _beginCountdownThenRun() {
    _timer?.cancel();
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastAttemptTs = now;
    ref.read(focusLogRepositoryProvider).append(
          FocusLogEvent(
            type: FocusLogEventType.focusAttempt,
            tsMs: now,
            dateKey: _todayKey(),
            meta: {'modeMinutes': _selectedMinutes},
          ),
        );
    setState(() {
      _countdown = 3;
      _running = false;
      _onBreak = false;
      _leaveHint = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
          if (_countdown == 0) {
            _running = true;
            _onBreak = false;
            _sessionTotalSec = _selectedMinutes * 60;
            _remainingSec = _sessionTotalSec;
            ref.read(focusLogRepositoryProvider).append(
                  FocusLogEvent(
                    type: FocusLogEventType.focusStarted,
                    tsMs: DateTime.now().millisecondsSinceEpoch,
                    dateKey: _todayKey(),
                    meta: {'modeMinutes': _selectedMinutes, 'attemptTs': _lastAttemptTs},
                  ),
                );
          }
        } else if (_running && _onBreak) {
          if (_breakRemainingSec > 0) {
            _breakRemainingSec--;
          }
          if (_breakRemainingSec <= 0) {
            _onBreak = false;
            _breakRemainingSec = _breakDurationSec;
          }
        } else if (_running && !_onBreak && _remainingSec > 0) {
          _remainingSec--;
        } else if (_running && !_onBreak && _remainingSec <= 0) {
          t.cancel();
          _running = false;
          _onBreak = false;
          ref.read(focusLogRepositoryProvider).append(
                FocusLogEvent(
                  type: FocusLogEventType.focusCompleted,
                  tsMs: DateTime.now().millisecondsSinceEpoch,
                  dateKey: _todayKey(),
                  meta: {
                    'modeMinutes': _selectedMinutes,
                    'durationSec': _sessionTotalSec,
                  },
                ),
              );
        }
      });
    });
  }

  void _startFiveMinuteBreak() {
    if (!_running || _onBreak || _countdown > 0) return;
    if (_remainingSec <= 0) return;
    final total = _sessionTotalSec <= 0 ? 1 : _sessionTotalSec;
    setState(() {
      _onBreak = true;
      _breakRemainingSec = _breakDurationSec;
      _frozenRingProgress = (1.0 - (_remainingSec / total)).clamp(0.0, 1.0);
    });
  }

  void _resumeFromBreak() {
    if (!_onBreak) return;
    setState(() {
      _onBreak = false;
      _breakRemainingSec = _breakDurationSec;
    });
  }

  Future<void> _onNudgeSheet() async {
    ref.read(focusLogRepositoryProvider).append(
          FocusLogEvent(
            type: FocusLogEventType.distraction,
            tsMs: DateTime.now().millisecondsSinceEpoch,
            dateKey: _todayKey(),
            meta: {'source': 'userButton'},
          ),
        );
    final ctx = ref.read(userLifeContextProvider);
    final text = await ref.read(aiAgentServiceProvider).nudgeBackFromDistraction(
          currentTaskTitle: '현재 작업',
          context: ctx,
        );
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncBlocks = ref.watch(todayBlocksProvider);
    final total = _sessionTotalSec <= 0 ? 1 : _sessionTotalSec;
    final flow = _running && !_onBreak ? (1.0 - (_remainingSec / total)).clamp(0.0, 1.0) : 0.0;
    final ringProgress = _onBreak ? _frozenRingProgress : flow;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final headline = _onBreak
        ? '5분 휴식'
        : (_running ? _format(_remainingSec) : '시작 대기');
    const breakCenterColor = Color(0xFF0D9F6C);

    return Scaffold(
      backgroundColor: AppChrome.pageBackground,
      appBar: AppBar(
        backgroundColor: AppChrome.topBarBackground,
        foregroundColor: AppChrome.topBarForeground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text('집중 모드'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_countdown > 0) ...[
                      const SizedBox(height: 24),
                      Text(
                        '$_countdown',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: const Color(0xFF2C3140),
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '곧 집중이 시작돼요',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6B7080),
                            ),
                      ),
                    ] else ...[
                      Center(
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment<int>(value: 50, label: Text('50분')),
                            ButtonSegment<int>(value: 25, label: Text('25분')),
                          ],
                          selected: {_selectedMinutes},
                          onSelectionChanged: (_running || _onBreak)
                              ? null
                              : (next) {
                                  if (next.isEmpty) return;
                                  setState(() {
                                    _selectedMinutes = next.first;
                                    _sessionTotalSec = _selectedMinutes * 60;
                                    _remainingSec = _sessionTotalSec;
                                  });
                                },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: _onBreak ? breakCenterColor : const Color(0xFF2C3140),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 16),
                      TimeFlowRing(
                        progress: ringProgress.clamp(0.0, 1.0),
                        centerLabel: _onBreak ? _format(_breakRemainingSec) : _format(_remainingSec),
                        centerColor: _onBreak ? breakCenterColor : null,
                      ),
                      const SizedBox(height: 16),
                      DecoratedBox(
                        decoration: AppChrome.softCardDecoration(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  '이탈이 아니라 자료찾기 중이에요!',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: const Color(0xFF2C3140),
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                ),
                              ),
                              Switch.adaptive(
                                value: _taskLookupNotLeave,
                                onChanged: _countdown > 0
                                    ? null
                                    : (v) => setState(() => _taskLookupNotLeave = v),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_leaveHint != null) ...[
                      const SizedBox(height: 16),
                      LeaveHintCard(text: _leaveHint!),
                    ],
                    const SizedBox(height: 16),
                    asyncBlocks.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (blocks) => _FocusChecklistCard(
                        blocks: blocks,
                        onToggle: (block, unitId, done) => _toggleUnit(block, unitId, done),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const ParkedThoughtsCard(),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _onNudgeSheet,
                      icon: const Icon(Icons.psychology_alt_outlined),
                      label: const Text('딴생각 정리 (AI)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2C3140),
                        side: const BorderSide(color: AppChrome.softBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Material(
              elevation: 8,
              shadowColor: Colors.black12,
              color: AppChrome.pageBackground,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 12 + bottomInset),
                child: _buildBottomPrimaryButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPrimaryButton() {
    if (_countdown > 0) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFB8BCC8),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: null,
        child: const Text(
          '시작 준비 중…',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
    }
    if (_onBreak) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0D9F6C),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _resumeFromBreak,
        child: const Text(
          '다시 시작',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
    }
    if (_running) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFE67E22),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _remainingSec > 0 ? _startFiveMinuteBreak : null,
        child: const Text(
          '5분 휴식',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
    }
    return FilledButton(
      style: AppChrome.primaryActionNavyStyle.copyWith(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
      ),
      onPressed: _beginCountdownThenRun,
      child: const Text('강제시작'),
    );
  }

  String _format(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleUnit(TaskBlock block, String unitId, bool done) async {
    final repo = ref.read(planningRepositoryProvider);
    final next = block.units
        .map((u) => u.id == unitId ? u.copyWith(isDone: done) : u)
        .toList();

    await repo.updateBlock(block.copyWith(units: next));
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(backlogBlocksProvider);
    ref.invalidate(canAddNewBlockProvider);
  }
}

class _FocusChecklistCard extends StatelessWidget {
  const _FocusChecklistCard({
    required this.blocks,
    required this.onToggle,
  });

  final List<TaskBlock> blocks;
  final Future<void> Function(TaskBlock block, String unitId, bool done) onToggle;

  @override
  Widget build(BuildContext context) {
    final current = blocks.firstWhere(
      (b) => !b.isFullyComplete,
      orElse: () => blocks.isEmpty ? TaskBlock(id: '', title: '', units: []) : blocks.first,
    );
    if (current.id.isEmpty || current.units.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: AppChrome.softCardDecoration(),
        child: Text(
          '오늘 블록이 없거나 단계가 없어요. “오늘 블록”에서 추가/쪼개기를 해보세요.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6B7080),
              ),
        ),
      );
    }

    final view = current.units.take(6).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      decoration: AppChrome.softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '지금 할 일',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppChrome.heroAccentBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            current.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF2C3140),
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 8),
          for (final u in view)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: u.isDone,
              title: Text(
                u.title,
                style: const TextStyle(color: Color(0xFF2C3140)),
              ),
              onChanged: (v) => onToggle(current, u.id, v ?? false),
            ),
        ],
      ),
    );
  }
}
