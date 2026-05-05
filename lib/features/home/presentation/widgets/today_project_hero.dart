import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../gamification/domain/player_progress.dart';

/// 상단에 고정되는 한 줄: 제목 + 우측 액션 (레벨·집중 시작 제외).
class TodayProjectHeroPinnedTitleBar extends StatelessWidget {
  const TodayProjectHeroPinnedTitleBar({
    super.key,
    this.heroTitle = '오늘의 프로젝트',
    this.leadingActions = const [],
  });

  final String heroTitle;
  final List<Widget> leadingActions;

  static const _cardBg = Color(0xFF1F212A);

  static double scrollExtent(BuildContext context) {
    final safeTop = math.max(MediaQuery.paddingOf(context).top, 4.0);
    const verticalPad = 8.0;
    const titleRow = 52.0;
    return safeTop + verticalPad + titleRow + verticalPad;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardBg,
      child: SafeArea(
        bottom: false,
        minimum: const EdgeInsets.only(top: 4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
          child: _TodayProjectHeroTitleRow(
            heroTitle: heroTitle,
            leadingActions: leadingActions,
          ),
        ),
      ),
    );
  }
}

class _HeroLevelStatsSection extends StatelessWidget {
  const _HeroLevelStatsSection({required this.progress});

  final PlayerProgress progress;

  static const _trackBg = Color(0xFF2E323C);
  static const _muted = Color(0xFFB8BCC8);

  @override
  Widget build(BuildContext context) {
    final need = PlayerProgress.xpForLevel(progress.level);
    final ratio = need == 0 ? 0.0 : progress.xp / need;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
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
          ),
        ),
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
  });

  final PlayerProgress progress;
  final bool lowEnergy;
  final VoidCallback onStartFocus;

  static const _cardBg = Color(0xFF1F212A);
  static const _accentRed = Color(0xFFE52D3D);

  static const double _focusButtonInset = 88;
  static const double _focusButtonHeight = 82;
  static const double _hitExtendBelowCard = 54;
  static const double _focusButtonBottomOffset = -10;
  /// 아래 카드와 버튼 영역 여백 — 줄일수록 카드가 더 위로 붙음.
  static const double _heroBottomPadding = 64;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _heroBottomPadding),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 52),
                  child: _HeroLevelStatsSection(progress: progress),
                ),
              ),
              const SizedBox(height: _hitExtendBelowCard),
            ],
          ),
          Positioned(
            left: _focusButtonInset,
            right: _focusButtonInset,
            bottom: _focusButtonBottomOffset,
            height: _focusButtonHeight,
            child: Material(
              color: _accentRed,
              elevation: 4,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onStartFocus,
                child: SizedBox.expand(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, size: 28, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        lowEnergy ? '딱 5분만 시작' : '집중 시작',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.25,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            heroTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
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

  static const _cardBg = Color(0xFF1F212A);
  static const _accentRed = Color(0xFFE52D3D);

  static const double _focusButtonInset = 88;
  static const double _focusButtonHeight = 82;
  static const double _hitExtendBelowCard = 54;
  static const double _focusButtonBottomOffset = -10;
  static const double _heroBottomPadding = 102;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _heroBottomPadding),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                ),
                child: SafeArea(
                  bottom: false,
                  minimum: const EdgeInsets.only(top: 4),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 52),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TodayProjectHeroTitleRow(
                          heroTitle: heroTitle,
                          leadingActions: leadingActions,
                        ),
                        const SizedBox(height: 22),
                        _HeroLevelStatsSection(progress: progress),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: _hitExtendBelowCard),
            ],
          ),
          Positioned(
            left: _focusButtonInset,
            right: _focusButtonInset,
            bottom: _focusButtonBottomOffset,
            height: _focusButtonHeight,
            child: Material(
              color: _accentRed,
              elevation: 4,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onStartFocus,
                child: SizedBox.expand(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, size: 28, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        lowEnergy ? '딱 5분만 시작' : '집중 시작',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.25,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
