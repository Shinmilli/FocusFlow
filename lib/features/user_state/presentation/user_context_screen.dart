import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_chrome.dart';
import '../domain/user_life_context.dart';
import 'daily_context_gate_providers.dart';
import 'user_context_providers.dart';

class UserContextScreen extends ConsumerStatefulWidget {
  const UserContextScreen({super.key});

  @override
  ConsumerState<UserContextScreen> createState() => _UserContextScreenState();
}

class _UserContextScreenState extends ConsumerState<UserContextScreen> {
  late double _sleep;
  late int _stress;
  late bool _phone;
  late bool _exam;
  late bool _burnout;

  @override
  void initState() {
    super.initState();
    final c = ref.read(userLifeContextProvider);
    _sleep = c.sleepHours;
    _stress = c.stressLevel;
    _phone = c.phoneHeavyUse;
    _exam = c.examPeriod;
    _burnout = c.burnoutRisk;
  }

  @override
  Widget build(BuildContext context) {
    final mult = ref.watch(userLifeContextProvider).planIntensityMultiplier;

    return Scaffold(
      backgroundColor: AppChrome.pageBackground,
      appBar: AppBar(title: const Text('오늘 상태')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            width: double.infinity,
            decoration: AppChrome.softCardDecoration(),
            padding: const EdgeInsets.all(14),
            child: Text(
              '이 값들은 AI가 오늘 계획 강도를 자동으로 줄이거나 늘릴 때 씁니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5C6378)),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            decoration: AppChrome.softCardDecoration(),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Text(
            '수면 시간: ${_sleep.toStringAsFixed(1)}h',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF1A1C26)),
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
          SwitchListTile(
            title: const Text('스마트폰 과의존 느낌'),
            value: _phone,
            onChanged: (v) => setState(() => _phone = v),
          ),
          SwitchListTile(
            title: const Text('시험기간'),
            value: _exam,
            onChanged: (v) => setState(() => _exam = v),
          ),
          SwitchListTile(
            title: const Text('번아웃 위험'),
            value: _burnout,
            onChanged: (v) => setState(() => _burnout = v),
          ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            decoration: AppChrome.softCardDecoration(),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('오늘 계획 강도 승수'),
            subtitle: Text(mult.toStringAsFixed(2)),
          ),
          FilledButton(
            style: AppChrome.primaryActionNavyStyle,
            onPressed: () {
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
              if (!context.mounted) return;
              context.go('/');
            },
            child: const Text('저장'),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
