import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/responsive_layout.dart';
import '../../ai_agent/presentation/ai_assistant_hub.dart';
import '../../auth/domain/auth_state.dart';
import '../../gamification/presentation/gamification_providers.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../flow_track/presentation/flow_track_providers.dart';
import '../../mcp/presentation/mcp_organize_flow.dart';
import '../../planning/domain/task_block.dart';
import '../../planning/presentation/planning_providers.dart';
import '../../planning/presentation/planning_screen.dart';
import 'widgets/home_desktop_side_panel.dart';
import 'widgets/home_task_grid_layout.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = ResponsiveLayout.useExpandedLayout(context, constraints);
        return _buildHome(context, expanded, constraints);
      },
    );
  }

  Widget _buildHome(BuildContext context, bool expanded, BoxConstraints constraints) {
    final progress = ref.watch(playerProgressProvider);
    final ctx = ref.watch(userLifeContextProvider);
    final lowEnergy = ctx.sleepHours < 6 || ctx.stressLevel >= 4;
    final asyncBlocks = ref.watch(todayBlocksProvider);
    final segs = ref.watch(flowWeekSegmentsProvider).valueOrNull;
    final tierEn = (segs != null && segs.isNotEmpty) ? segs.last.tier : 'Iron';

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
        icon: Icon(Icons.refresh, color: Colors.white.withValues(alpha: 0.92)),
        visualDensity: VisualDensity.compact,
      ),
    ];

    final pinnedTitle = TodayProjectHeroPinnedTitleBar(
      leadingActions: heroActions,
    );
    final headerExtent = TodayProjectHeroPinnedTitleBar.scrollExtent(context);

    final heroScrollBody = TodayProjectHeroScrollBody(
      progress: progress,
      lowEnergy: lowEnergy,
      onStartFocus: () => context.push('/focus'),
      tierEn: tierEn,
      onTapTier: () => context.push('/flow-track'),
      aiAdvice: '지금은 “다음 한 단계”만.',
      showNumericStats: false,
    );

    Widget scrollHome(List<Widget> bodySlivers) {
      final scroll = CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _HomePinnedHeroDelegate(extent: headerExtent, child: pinnedTitle),
          ),
          ...bodySlivers,
        ],
      );

      if (!expanded) return scroll;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: scroll,
          ),
          Expanded(
            flex: 2,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: HomeDesktopSidePanel.minWidth),
              child: const HomeDesktopSidePanel(),
            ),
          ),
        ],
      );
    }

    return asyncBlocks.when(
      loading: () => scrollHome([
        SliverToBoxAdapter(child: heroScrollBody),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ]),
      error: (e, _) => scrollHome([
        SliverToBoxAdapter(child: heroScrollBody),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('$e')),
        ),
      ]),
      data: (blocks) {
        final list = _orderedBlocks(blocks);
        final gridCrossCount = expanded
            ? HomeTaskGridLayout.crossAxisCountForWidth(
                ResponsiveLayout.layoutWidth(context, constraints),
              )
            : HomeTaskGridLayout.compactCrossCount;
        final gridPadding = expanded
            ? HomeTaskGridLayout.gridPaddingExpanded
            : HomeTaskGridLayout.gridPaddingCompact;
        return scrollHome([
          SliverToBoxAdapter(child: heroScrollBody),
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
                      onPressed: () => openMcpOrganizeFlow(context, ref),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('외부 일정 · 할 일 AI 정리'),
                    ),
                    const SizedBox(height: 8),
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
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gridPadding, 0, gridPadding, 4),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: gridCrossCount,
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
      child: Material(
        color: Colors.transparent,
        elevation: shrinkOffset > 0 ? 3 : 0,
        shadowColor: Colors.black26,
        child: ClipRect(child: child),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomePinnedHeroDelegate oldDelegate) =>
      extent != oldDelegate.extent || child != oldDelegate.child;
}
