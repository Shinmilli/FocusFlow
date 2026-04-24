import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../focus_session/domain/focus_log_event.dart';
import '../../focus_session/presentation/focus_log_providers.dart';
import '../../gamification/presentation/gamification_providers.dart';
import '../../planning/presentation/planning_providers.dart';
import 'insights_providers.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playerProgressProvider);
    final asyncEvents = ref.watch(focusLogEventsProvider);
    final asyncBlocks = ref.watch(todayBlocksProvider);
    final asyncDerived = ref.watch(derivedSignalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('기록/통계'),
        actions: [
          IconButton(
            tooltip: '로그 초기화(개발용)',
            onPressed: () async {
              await ref.read(focusLogRepositoryProvider).clear();
              ref.invalidate(focusLogEventsProvider);
              ref.invalidate(derivedSignalsProvider);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('로그를 초기화했어요')),
              );
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ref.watch(todaySummaryProvider).when(
                loading: () => const _LoadingCard(title: '오늘 요약'),
                error: (e, _) => _ErrorCard(title: '오늘 요약', error: '$e'),
                data: (text) => _StatCard(
                  title: '오늘 요약',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => ref.invalidate(todaySummaryProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('다시 생성'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 12),
          _StatCard(
            title: '레벨/스트릭',
            child: Text('Lv.${progress.level} · 스트릭 ${progress.streakDays}일'),
          ),
          const SizedBox(height: 12),
          asyncBlocks.when(
            loading: () => const _LoadingCard(title: '오늘 완료한 블록'),
            error: (e, _) => _ErrorCard(title: '오늘 완료한 블록', error: '$e'),
            data: (blocks) {
              final done = blocks.where((b) => b.isFullyComplete).length;
              return _StatCard(
                title: '오늘 완료한 블록',
                child: Text('$done / ${blocks.length}'),
              );
            },
          ),
          const SizedBox(height: 12),
          asyncDerived.when(
            loading: () => const _LoadingCard(title: '시작/이탈 패턴'),
            error: (e, _) => _ErrorCard(title: '시작/이탈 패턴', error: '$e'),
            data: (d) => _StatCard(
              title: '시작/이탈 패턴',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('최근 시작 지연: ${d.minutesToStart}분'),
                  const SizedBox(height: 4),
                  Text('오늘 이탈/딴생각: ${d.distractionCountToday}회'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          asyncEvents.when(
            loading: () => const _LoadingCard(title: '최근 로그'),
            error: (e, _) => _ErrorCard(title: '최근 로그', error: '$e'),
            data: (events) {
              final view = events.reversed.take(30).toList();
              return _StatCard(
                title: '최근 로그(최대 30개)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in view)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(_fmtEvent(e)),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _fmtEvent(FocusLogEvent e) {
    final type = e.type.name;
    final dt = DateTime.fromMillisecondsSinceEpoch(e.tsMs);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final dateKey = e.dateKey;
    return '[$hh:$mm] $type ${dateKey.isEmpty ? '' : '($dateKey)'}';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _StatCard(
      title: title,
      child: const LinearProgressIndicator(),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.title, required this.error});

  final String title;
  final String error;

  @override
  Widget build(BuildContext context) {
    return _StatCard(
      title: title,
      child: Text(error),
    );
  }
}

