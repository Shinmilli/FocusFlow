import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_config.dart';
import '../../ai_agent/presentation/ai_assistant_hub.dart';
import '../../auth/domain/auth_state.dart';
import '../../gamification/presentation/gamification_providers.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../planning/domain/task_block.dart';
import '../../planning/presentation/planning_providers.dart';
import '../../planning/presentation/planning_screen.dart';
import 'widgets/today_project_hero.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPostLoginAiPlan());
  }

  Future<void> _maybeShowPostLoginAiPlan() async {
    if (!mounted) return;
    if (ref.read(authControllerProvider).phase != AuthPhase.authenticated) return;
    final pending = ref.read(authControllerProvider.notifier).consumePendingAiTodayPlanOnHome();
    if (!pending) return;
    await openAiTodayPlanProposal(context, ref);
  }

  static List<TaskBlock> _orderedBlocks(List<TaskBlock> blocks) {
    final current = blocks.where((b) => b.isCurrentTask).toList();
    final incomplete = blocks.where((b) => !b.isFullyComplete && !b.isCurrentTask).toList();
    final complete = blocks.where((b) => b.isFullyComplete && !b.isCurrentTask).toList();
    return [...current, ...incomplete, ...complete];
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(playerProgressProvider);
    final ctx = ref.watch(userLifeContextProvider);
    final lowEnergy = ctx.sleepHours < 6 || ctx.stressLevel >= 4;
    final asyncBlocks = ref.watch(todayBlocksProvider);

    void refreshHome() {
      ref.invalidate(playerProgressProvider);
      ref.invalidate(todayBlocksProvider);
      ref.invalidate(backlogBlocksProvider);
      ref.invalidate(canAddNewBlockProvider);
    }

    final heroActions = <Widget>[
      IconButton(
        tooltip: '새로고침',
        onPressed: refreshHome,
        icon: Icon(Icons.refresh, color: Colors.white.withOpacity(0.92)),
        visualDensity: VisualDensity.compact,
      ),
      if (kApiBaseUrlConfigured)
        IconButton(
          tooltip: '로그아웃',
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).logout();
          },
          icon: Icon(Icons.logout, color: Colors.white.withOpacity(0.92)),
          visualDensity: VisualDensity.compact,
        ),
    ];

    final hero = TodayProjectHero(
      progress: progress,
      lowEnergy: lowEnergy,
      onStartFocus: () => context.push('/focus'),
      leadingActions: heroActions,
    );
    final headerExtent = TodayProjectHero.pinnedScrollExtent(context);

    Widget scrollHome(List<Widget> bodySlivers) {
      return CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _HomePinnedHeroDelegate(extent: headerExtent, child: hero),
          ),
          ...bodySlivers,
        ],
      );
    }

    return asyncBlocks.when(
      loading: () => scrollHome(const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ]),
      error: (e, _) => scrollHome([
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('$e')),
        ),
      ]),
      data: (blocks) {
        final list = _orderedBlocks(blocks);
        return scrollHome([
          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '지금은 “다음 한 단계”만.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '계획 강도 ×${ctx.planIntensityMultiplier.toStringAsFixed(2)} · 수면 ${ctx.sleepHours.toStringAsFixed(1)}h · 스트레스 ${ctx.stressLevel}/5',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '오늘 선택된 블록이 없어요',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF6B7080),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '아래 + 로 블록을 추가하거나 오늘 블록 화면에서 고를 수 있어요.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8E93A3),
                          ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => context.push('/plan/add'),
                      icon: const Icon(Icons.add),
                      label: const Text('블록 추가'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.push('/plan'),
                      child: const Text('오늘 블록 전체 관리'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childCount: list.length,
                itemBuilder: (context, index) {
                  final block = list[index];
                  return PlanningScreen.taskGridCard(context, ref, block);
                },
              ),
            ),
          ],
          if (lowEnergy)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '컨디션이 낮은 날이에요. 오늘은 5분부터 시작해도 충분해요.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]);
      },
    );
  }
}

class _HomePinnedHeroDelegate extends SliverPersistentHeaderDelegate {
  _HomePinnedHeroDelegate({
    required this.extent,
    required this.child,
  });

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: extent,
      width: double.infinity,
      child: ClipRect(child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _HomePinnedHeroDelegate oldDelegate) =>
      extent != oldDelegate.extent || child != oldDelegate.child;
}
