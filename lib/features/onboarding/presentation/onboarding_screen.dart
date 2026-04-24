import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../user_state/presentation/user_context_providers.dart';
import 'onboarding_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(userLifeContextProvider);
    final pages = <Widget>[
      _Intro(onNext: () => setState(() => _step = 1)),
      _QuickCheck(
        sleepHours: ctx.sleepHours,
        stress: ctx.stressLevel,
        phoneHeavyUse: ctx.phoneHeavyUse,
        onDone: () async {
          await ref.read(onboardingPrefsProvider).setDone(true);
          if (!context.mounted) return;
          context.go('/');
        },
        onAdjustContext: () => context.push('/context'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('시작하기'),
        automaticallyImplyLeading: false,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: pages[_step],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('intro'),
      padding: const EdgeInsets.all(24),
      children: [
        Text('FocusFlow', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          '오늘은 딱 3개 블록만. 그리고 “다음 한 단계”부터 시작해요.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이 앱이 도와주는 것', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                const Text('1) 큰 일을 바로 시작 가능한 단계로 쪼개기'),
                const Text('2) 집중 시작을 5분부터 쉽게 만들기'),
                const Text('3) 딴생각/이탈 후 다시 돌아오는 한 문장'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onNext,
          child: const Text('30초만 체크하고 시작'),
        ),
        const SizedBox(height: 8),
        Text(
          'Tip: 완벽한 계획보다 “시작”이 목표예요.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _QuickCheck extends StatelessWidget {
  const _QuickCheck({
    required this.sleepHours,
    required this.stress,
    required this.phoneHeavyUse,
    required this.onDone,
    required this.onAdjustContext,
  });

  final double sleepHours;
  final int stress;
  final bool phoneHeavyUse;
  final Future<void> Function() onDone;
  final VoidCallback onAdjustContext;

  @override
  Widget build(BuildContext context) {
    final lowEnergy = sleepHours < 6 || stress >= 4;
    return ListView(
      key: const ValueKey('quick'),
      padding: const EdgeInsets.all(24),
      children: [
        Text('오늘 상태', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          lowEnergy ? '컨디션이 낮으면 더 작은 첫 단계가 좋아요.' : '좋아요. 오늘은 가볍게 시작해요.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('요약', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text('수면: ${sleepHours.toStringAsFixed(1)}시간'),
                Text('스트레스: $stress/5'),
                Text('폰 과다 사용: ${phoneHeavyUse ? '예' : '아니오'}'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onAdjustContext,
                  icon: const Icon(Icons.tune),
                  label: const Text('상태 조정하기'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => onDone(),
          child: Text(lowEnergy ? '오늘은 5분부터 시작' : '시작하기'),
        ),
      ],
    );
  }
}

