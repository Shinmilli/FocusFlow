import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/layout/responsive_layout.dart';
import '../../../../app/theme/app_chrome.dart';
import '../../../flow_track/presentation/flow_track_tier_style.dart';
import '../../../gamification/domain/player_progress.dart';

abstract final class _HeroLayout {
  static const horizontalMarginCompact = 16.0;
  static const borderRadius = 22.0;
  static const cardBg = Color(0xFF1F212A);
  static const accentRed = Color(0xFFE52D3D);
  static const focusBtnWidthCompact = 200.0;
  static const focusBtnWidthExpanded = 260.0;
  static const focusBtnHeightCompact = 68.0;
  static const focusBtnHeightExpanded = 72.0;

  static double focusBtnWidth(BuildContext context) =>
      ResponsiveLayout.isExpanded(context) ? focusBtnWidthExpanded : focusBtnWidthCompact;

  static double focusBtnHeight(BuildContext context) =>
      ResponsiveLayout.isExpanded(context) ? focusBtnHeightExpanded : focusBtnHeightCompact;

  static double horizontalMargin(BuildContext context) =>
      ResponsiveLayout.isExpanded(context) ? 0 : horizontalMarginCompact;
}

class _FocusStartButton extends StatelessWidget {
  const _FocusStartButton({
    required this.onTap,
    required this.lowEnergy,
  });

  final VoidCallback onTap;
  final bool lowEnergy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _HeroLayout.accentRed,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: _HeroLayout.focusBtnWidth(context),
          height: _HeroLayout.focusBtnHeight(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, size: 26, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                lowEnergy ? '5분 시작' : '집중 시작',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 상단에 고정되는 한 줄: 제목 + 우측 액션 (레벨·집중 시작 제외).
class TodayProjectHeroPinnedTitleBar extends StatelessWidget {
  const TodayProjectHeroPinnedTitleBar({
    super.key,
    this.heroTitle = '오늘의 프로젝트',
    this.leadingActions = const [],
  });

  final String heroTitle;
  final List<Widget> leadingActions;

  static double scrollExtent(BuildContext context) {
    final safeTop = math.max(MediaQuery.paddingOf(context).top, 4.0);
    const verticalPad = 8.0;
    const titleRow = 52.0;
    return safeTop + verticalPad + titleRow + verticalPad;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppChrome.pageBackground,
      child: SafeArea(
        bottom: false,
        minimum: const EdgeInsets.only(top: 4),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _HeroLayout.horizontalMargin(context),
            8,
            _HeroLayout.horizontalMargin(context),
            0,
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: _HeroLayout.cardBg,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(_HeroLayout.borderRadius),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
              child: _TodayProjectHeroTitleRow(
                heroTitle: heroTitle,
                leadingActions: leadingActions,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroLevelStatsSection extends StatelessWidget {
  const _HeroLevelStatsSection({
    required this.progress,
    required this.tierEn,
    this.onTapTier,
    this.advice,
    this.showNumericStats = true,
    this.onStartFocus,
    this.lowEnergy = false,
  });

  final PlayerProgress progress;
  final String tierEn;
  final VoidCallback? onTapTier;
  final Widget? advice;
  final bool showNumericStats;
  final VoidCallback? onStartFocus;
  final bool lowEnergy;

  static const _trackBg = Color(0xFF2E323C);
  static const _muted = Color(0xFFB8BCC8);

  @override
  Widget build(BuildContext context) {
    final tierBg = FlowTrackTierStyle.accent(tierEn);
    final tierFg = FlowTrackTierStyle.onAccent(tierBg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (advice != null) ...[
          advice!,
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTapTier,
              borderRadius: BorderRadius.circular(999),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tierBg.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tierFg.withValues(alpha: 0.9)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.military_tech_rounded, size: 16, color: tierFg),
                      const SizedBox(width: 6),
                      Text(
                        tierEn,
                        style: TextStyle(
                          color: tierFg,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 18, color: tierFg.withValues(alpha: 0.85)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _buildLevelAndFocusRow(context),
        ),
        if (showNumericStats) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                '연속 ${progress.streakDays}일',
                style: TextStyle(
                  color: _muted.withValues(alpha: 0.95),
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 18),
              Text(
                '누적 ${progress.totalBlocksCompleted}블록',
                style: TextStyle(
                  color: _muted.withValues(alpha: 0.95),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _levelProgressRow(Color primary, int need, double ratio) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LEVEL',
              style: TextStyle(
                color: _muted.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lv.${progress.level}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: _trackBg,
              color: primary,
            ),
          ),
        ),
        if (showNumericStats) ...[
          const SizedBox(width: 12),
          Text(
            '${progress.xp}/$need',
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLevelAndFocusRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final primary = Theme.of(context).colorScheme.primary;
        final need = PlayerProgress.xpForLevel(progress.level);
        final ratio = need == 0 ? 0.0 : progress.xp / need;
        final compact = ResponsiveLayout.isCompactConstraints(constraints);

        if (compact && onStartFocus != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _levelProgressRow(primary, need, ratio),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.center,
                child: _FocusStartButton(onTap: onStartFocus!, lowEnergy: lowEnergy),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _levelProgressRow(primary, need, ratio)),
            if (onStartFocus != null) ...[
              const SizedBox(width: 20),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: _FocusStartButton(onTap: onStartFocus!, lowEnergy: lowEnergy),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 레벨·진행·통계·집중 시작 — 스크롤되는 본문 (타이틀 바 아래).
class TodayProjectHeroScrollBody extends StatelessWidget {
  const TodayProjectHeroScrollBody({
    super.key,
    required this.progress,
    required this.lowEnergy,
    required this.onStartFocus,
    this.tierEn = 'Iron',
    this.onTapTier,
    this.aiAdvice,
    this.showNumericStats = true,
  });

  final PlayerProgress progress;
  final bool lowEnergy;
  final VoidCallback onStartFocus;
  final String tierEn;
  final VoidCallback? onTapTier;
  final String? aiAdvice;
  final bool showNumericStats;

  static const double _heroBottomPadding = 16;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _HeroLayout.horizontalMargin(context),
        0,
        _HeroLayout.horizontalMargin(context),
        _heroBottomPadding,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _HeroLayout.cardBg,
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(_HeroLayout.borderRadius),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          child: _HeroLevelStatsSection(
            progress: progress,
            tierEn: tierEn,
            onTapTier: onTapTier,
            showNumericStats: showNumericStats,
            onStartFocus: onStartFocus,
            lowEnergy: lowEnergy,
            advice: aiAdvice == null
                ? null
                : Text(
                    aiAdvice!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _TodayProjectHeroTitleRow extends StatelessWidget {
  const _TodayProjectHeroTitleRow({
    required this.heroTitle,
    required this.leadingActions,
  });

  final String heroTitle;
  final List<Widget> leadingActions;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge ??
        const TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
    final titleStyle = base.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.15,
    );

    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            heroTitle,
            style: titleStyle,
          ),
          if (leadingActions.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: leadingActions,
              ),
            ),
        ],
      ),
    );
  }
}

/// 메인 상단 "오늘의 프로젝트" 히어로 카드 (레벨·진행·집중 시작) — 단일 스크롤 화면용.
class TodayProjectHero extends StatelessWidget {
  const TodayProjectHero({
    super.key,
    required this.progress,
    required this.lowEnergy,
    required this.onStartFocus,
    this.heroTitle = '오늘의 프로젝트',
    this.leadingActions = const [],
  });

  final PlayerProgress progress;
  final bool lowEnergy;
  final VoidCallback onStartFocus;
  final String heroTitle;
  final List<Widget> leadingActions;

  static const double _heroBottomPadding = 16;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _HeroLayout.horizontalMargin(context),
        0,
        _HeroLayout.horizontalMargin(context),
        _heroBottomPadding,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _HeroLayout.cardBg,
          borderRadius: BorderRadius.circular(_HeroLayout.borderRadius),
        ),
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.only(top: 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TodayProjectHeroTitleRow(
                  heroTitle: heroTitle,
                  leadingActions: leadingActions,
                ),
                const SizedBox(height: 22),
                _HeroLevelStatsSection(
                  progress: progress,
                  tierEn: 'Iron',
                  onStartFocus: onStartFocus,
                  lowEnergy: lowEnergy,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
