import 'package:flutter/material.dart';

import '../../../gamification/domain/player_progress.dart';

/// 메인 상단 "오늘의 프로젝트" 히어로 카드 (레벨·진행·집중 시작).
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

  /// 홈·오늘 블록 등 동일 화면에서 제목만 바꿀 때 사용 (개념은 동일).
  final String heroTitle;

  /// 히어로 제목 줄 오른쪽에 표시할 아이콘 버튼들.
  final List<Widget> leadingActions;

  static const _cardBg = Color(0xFF1F212A);
  static const _accentRed = Color(0xFFE52D3D);
  static const _trackBg = Color(0xFF2E323C);
  static const _muted = Color(0xFFB8BCC8);

  static const double _focusButtonInset = 88;
  static const double _focusButtonHeight = 82;
  /// Stack hitTest가 카드 아래로 나간 버튼 영역까지 포함하도록 남기는 여백.
  static const double _hitExtendBelowCard = 24;

  @override
  Widget build(BuildContext context) {
    final need = PlayerProgress.xpForLevel(progress.level);
    final ratio = need == 0 ? 0.0 : progress.xp / need;
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 78),
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
                        SizedBox(
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
                        ),
                        const SizedBox(height: 22),
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
            bottom: 0,
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
