import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout/responsive_layout.dart';
import '../../../app/theme/app_chrome.dart';
import '../domain/user_life_context.dart';
import 'daily_context_gate_providers.dart';
import 'user_context_providers.dart';

/// 홈 데스크톱 우측·프로필 패널 등에 임베드하는 오늘 상태 폼.
class UserContextPanel extends ConsumerStatefulWidget {
  const UserContextPanel({
    super.key,
    this.compact = false,
    this.onSaved,
  });

  final bool compact;
  final VoidCallback? onSaved;

  @override
  ConsumerState<UserContextPanel> createState() => _UserContextPanelState();
}

class _UserContextPanelState extends ConsumerState<UserContextPanel> {
  late double _sleep;
  late int _stress;
  late bool _phone;
  late bool _exam;
  late bool _burnout;

  @override
  void initState() {
    super.initState();
    _syncFromProvider();
  }

  void _syncFromProvider() {
    final c = ref.read(userLifeContextProvider);
    _sleep = c.sleepHours;
    _stress = c.stressLevel;
    _phone = c.phoneHeavyUse;
    _exam = c.examPeriod;
    _burnout = c.burnoutRisk;
  }

  void _save() {
    ref.read(userLifeContextProvider.notifier).update(
          UserLifeContext(
            sleepHours: _sleep,
            stressLevel: _stress,
            phoneHeavyUse: _phone,
            examPeriod: _exam,
            burnoutRisk: _burnout,
          ),
        );
    ref.read(dailyContextGatePrefsProvider).markDoneForToday();
    ref.invalidate(dailyContextDoneProvider);
    widget.onSaved?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장했어요')),
    );
  }

  Widget _sliderSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '수면 시간: ${_sleep.toStringAsFixed(1)}h',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF1A1C26),
              ),
        ),
        Slider(
          value: _sleep,
          min: 0,
          max: 12,
          divisions: 24,
          label: '${_sleep.toStringAsFixed(1)}h',
          onChanged: (v) => setState(() => _sleep = v),
        ),
        Text('스트레스 (1–5): $_stress'),
        Slider(
          value: _stress.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '$_stress',
          onChanged: (v) => setState(() => _stress = v.round()),
        ),
      ],
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _toggleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toggleRow('스마트폰 과의존', _phone, (v) => setState(() => _phone = v)),
        _toggleRow('시험기간', _exam, (v) => setState(() => _exam = v)),
        _toggleRow('번아웃 위험', _burnout, (v) => setState(() => _burnout = v)),
      ],
    );
  }

  Widget _controlsSection(BuildContext context) {
    final useSplit = widget.compact || ResponsiveLayout.isExpanded(context);
    if (useSplit) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _sliderSection(context)),
          const SizedBox(width: 12),
          Expanded(child: _toggleSection()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sliderSection(context),
        const SizedBox(height: 4),
        _toggleSection(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mult = ref.watch(userLifeContextProvider).planIntensityMultiplier;
    final bodySmall = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF5C6378),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact)
          Text(
            '이 값들은 AI가 오늘 계획 강도를 자동으로 줄이거나 늘릴 때 씁니다.',
            style: bodySmall,
          ),
        if (!widget.compact) const SizedBox(height: 10),
        _controlsSection(context),
        const SizedBox(height: 6),
        Text(
          '오늘 계획 강도: ${mult.toStringAsFixed(2)}',
          style: bodySmall,
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: AppChrome.primaryActionNavyStyle.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(42)),
          ),
          onPressed: _save,
          child: const Text('저장'),
        ),
      ],
    );
  }
}
