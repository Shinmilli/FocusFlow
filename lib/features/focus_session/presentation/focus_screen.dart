import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout/desktop_nav_rail.dart';
import '../../../app/layout/responsive_layout.dart';
import '../../../app/theme/app_chrome.dart';
import '../../ai_agent/presentation/ai_providers.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../../planning/presentation/planning_providers.dart';
import 'focus_desktop_side_panel.dart';
import 'widgets/focus_checklist_panel.dart';
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
  static const double _expandedSideInset = 50;

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
    final expanded = ResponsiveLayout.isExpanded(context);
    final total = _sessionTotalSec <= 0 ? 1 : _sessionTotalSec;
    final flow = _running && !_onBreak ? (1.0 - (_remainingSec / total)).clamp(0.0, 1.0) : 0.0;
    final ringProgress = _onBreak ? _frozenRingProgress : flow;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final headline = _onBreak
        ? '5분 휴식'
        : (_running ? _format(_remainingSec) : '시작 대기');
    const breakCenterColor = Color(0xFF0D9F6C);

    final timerBody = _buildTimerBody(
      context,
      headline: headline,
      breakCenterColor: breakCenterColor,
      ringProgress: ringProgress,
    );

    final sideExtras = asyncBlocks.when(
      loading: () => expanded
          ? const SizedBox(
              width: FocusDesktopSidePanel.width,
              child: Center(child: CircularProgressIndicator()),
            )
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
      error: (_, __) => const SizedBox.shrink(),
      data: (blocks) {
        if (expanded) {
          return FocusDesktopSidePanel(
            blocks: blocks,
            taskLookupNotLeave: _taskLookupNotLeave,
            lookupToggleEnabled: _countdown == 0,
            onTaskLookupChanged: (v) => setState(() => _taskLookupNotLeave = v),
            onNudge: _onNudgeSheet,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_leaveHint != null) ...[
              LeaveHintCard(text: _leaveHint!),
              const SizedBox(height: 16),
            ],
            FocusChecklistPanel(blocks: blocks),
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
          ],
        );
      },
    );

    if (expanded) {
      return Scaffold(
        backgroundColor: AppChrome.pageBackground,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DesktopNavRail(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    color: AppChrome.topBarBackground,
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: 52,
                        child: Center(
                          child: Text(
                            '집중 모드',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppChrome.topBarForeground,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    _expandedSideInset,
                                    16,
                                    _expandedSideInset,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      timerBody,
                                      if (_leaveHint != null) ...[
                                        const SizedBox(height: 16),
                                        LeaveHintCard(text: _leaveHint!),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              Material(
                                elevation: 8,
                                shadowColor: Colors.black12,
                                color: AppChrome.pageBackground,
                                child: _buildBottomActionBar(bottomInset, expanded: true),
                              ),
                            ],
                          ),
                        ),
                        sideExtras,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                    timerBody,
                    const SizedBox(height: 16),
                    sideExtras,
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Material(
              elevation: 8,
              shadowColor: Colors.black12,
              color: AppChrome.pageBackground,
              child: _buildBottomActionBar(bottomInset, expanded: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerBody(
    BuildContext context, {
    required String headline,
    required Color breakCenterColor,
    required double ringProgress,
  }) {
    if (_countdown > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 25),
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
        const SizedBox(height: 25),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: _onBreak ? breakCenterColor : const Color(0xFF2C3140),
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 40),
        TimeFlowRing(
          progress: ringProgress.clamp(0.0, 1.0),
          centerLabel: _onBreak ? _format(_breakRemainingSec) : _format(_remainingSec),
          centerColor: _onBreak ? breakCenterColor : null,
        ),
        if (!ResponsiveLayout.isExpanded(context)) ...[
          const SizedBox(height: 40),
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
                    onChanged: (v) => setState(() => _taskLookupNotLeave = v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomActionBar(double bottomInset, {required bool expanded}) {
    if (expanded) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          _expandedSideInset,
          10,
          _expandedSideInset,
          12 + bottomInset,
        ),
        child: _buildBottomPrimaryButton(),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(32, 18, 32, 18 + bottomInset),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: SizedBox(
            width: double.infinity,
            child: _buildBottomPrimaryButton(),
          ),
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
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFE52D3D),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
}
