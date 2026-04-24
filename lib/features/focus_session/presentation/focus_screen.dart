import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/focus_flow_limits.dart';
import '../../ai_agent/presentation/ai_providers.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../domain/focus_log_event.dart';
import 'focus_log_providers.dart';
import 'widgets/leave_hint_card.dart';
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
  Timer? _timer;
  int _remainingSec = 25 * 60;
  int _countdown = 0;
  bool _running = false;
  bool _quick = false;
  String? _leaveHint;
  int? _lastAttemptTs;

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

  void _beginCountdownThenRun({required bool quick}) {
    _timer?.cancel();
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastAttemptTs = now;
    ref.read(focusLogRepositoryProvider).append(
          FocusLogEvent(
            type: FocusLogEventType.focusAttempt,
            tsMs: now,
            dateKey: _todayKey(),
            meta: {'quick': quick},
          ),
        );
    setState(() {
      _quick = quick;
      _countdown = 3;
      _running = false;
      _leaveHint = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
          if (_countdown == 0) {
            _running = true;
            _remainingSec = quick
                ? FocusFlowLimits.quickStartMinutes * 60
                : 25 * 60;
            ref.read(focusLogRepositoryProvider).append(
                  FocusLogEvent(
                    type: FocusLogEventType.focusStarted,
                    tsMs: DateTime.now().millisecondsSinceEpoch,
                    dateKey: _todayKey(),
                    meta: {'quick': quick, 'attemptTs': _lastAttemptTs},
                  ),
                );
          }
        } else if (_running && _remainingSec > 0) {
          _remainingSec--;
        } else if (_running && _remainingSec <= 0) {
          t.cancel();
          _running = false;
          ref.read(focusLogRepositoryProvider).append(
                FocusLogEvent(
                  type: FocusLogEventType.focusCompleted,
                  tsMs: DateTime.now().millisecondsSinceEpoch,
                  dateKey: _todayKey(),
                  meta: {
                    'quick': quick,
                    'durationSec': quick
                        ? FocusFlowLimits.quickStartMinutes * 60
                        : 25 * 60,
                  },
                ),
              );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _quick
        ? FocusFlowLimits.quickStartMinutes * 60
        : 25 * 60;
    final flow = _running ? 1.0 - (_remainingSec / total) : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('집중 모드')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_countdown > 0)
              Text(
                '$_countdown',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge,
              )
            else ...[
              Text(
                _running ? _format(_remainingSec) : '시작 대기',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              TimeFlowRing(progress: flow.clamp(0.0, 1.0)),
            ],
            if (_leaveHint != null) ...[
              const SizedBox(height: 16),
              LeaveHintCard(text: _leaveHint!),
            ],
            const Spacer(),
            FilledButton(
              onPressed: () => _beginCountdownThenRun(quick: false),
              child: const Text('강제 시작 (3초 카운트다운)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _beginCountdownThenRun(quick: true),
              child: const Text('딱 ${FocusFlowLimits.quickStartMinutes}분만'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
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
          if (!context.mounted) return;
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (c) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(text),
            ),
          );
        },
        label: const Text('딴생각 중'),
        icon: const Icon(Icons.psychology_alt_outlined),
      ),
    );
  }

  String _format(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
