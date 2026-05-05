import 'package:flutter/material.dart';

import '../../../planning/domain/task_block.dart';
import '../../../planning/domain/task_unit.dart';

/// 오늘 블록 그리드용 카드 (다크·화이트·라벤더 변형 + 원형 진행률).
class TodayTaskGridCard extends StatelessWidget {
  const TodayTaskGridCard({
    super.key,
    required this.block,
    required this.onTap,
    this.onSparkle,
    this.onToggleUnitDone,
    this.onEditChecklist,
    this.onSetCurrentTask,
    this.onDecompose,
    this.onDelete,
  });

  final TaskBlock block;
  final VoidCallback onTap;
  final VoidCallback? onSparkle;

  /// null이면 단계는 읽기 전용 bullets. 오늘 블록 화면에서 탭으로 완료 토글.
  final void Function(String unitId, bool done)? onToggleUnitDone;
  final VoidCallback? onEditChecklist;
  final VoidCallback? onSetCurrentTask;
  final VoidCallback? onDecompose;
  final VoidCallback? onDelete;

  static const _darkBg = Color(0xFF1F212A);
  static const _lavenderBg = Color(0xFFE0E0F2);
  static const _lavenderRing = Color(0xFF9B8FD9);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final complete = block.isFullyComplete;
    final current = block.isCurrentTask;
    final total = block.units.length;
    final done = block.units.where((u) => u.isDone).length;
    final ratio = total <= 0 ? 0.0 : done / total;

    late final Color bg;
    late final Color titleColor;
    late final Color bodyColor;
    late final Color bulletColor;
    late final Color ringTrack;
    late final Color ringProgress;

    if (complete) {
      bg = _lavenderBg;
      titleColor = const Color(0xFF9A9AB8);
      bodyColor = const Color(0xFFB4B4CA);
      bulletColor = bodyColor;
      ringTrack = _lavenderRing.withValues(alpha: 0.22);
      ringProgress = _lavenderRing.withValues(alpha: 0.55);
    } else if (current) {
      bg = _darkBg;
      titleColor = Colors.white;
      bodyColor = const Color(0xFFD0D4DE);
      bulletColor = bodyColor;
      ringTrack = Colors.white.withValues(alpha: 0.14);
      ringProgress = primary;
    } else {
      bg = Colors.white;
      titleColor = const Color(0xFF1A1C26);
      bodyColor = const Color(0xFF5C6378);
      bulletColor = bodyColor;
      ringTrack = const Color(0xFFE8EBF2);
      ringProgress = primary;
    }

    final plainWhite = !complete && !current;
    final planningInteractions = onToggleUnitDone != null;

    final sw = MediaQuery.sizeOf(context).width;
    final wideLayout = sw >= 600;
    final donutSize = wideLayout ? 108.0 : 80.0;
    final donutFontSize = wideLayout ? 18.0 : 15.0;
    final donutStroke = wideLayout ? 7.0 : 6.0;

    Widget listSection() {
      if (onToggleUnitDone != null) {
        return _InteractiveUnitList(
          units: block.units,
          color: bulletColor,
          accentBlue: complete ? _lavenderRing : primary,
          maxLines: 5,
          darkCard: current && !complete,
          onToggle: onToggleUnitDone!,
        );
      }
      if (complete) {
        return _CompletedUnitCheckList(
          units: block.units,
          textColor: bodyColor,
          checkColor: _lavenderRing,
          maxLines: 5,
        );
      }
      return _UnitBulletList(
        units: block.units,
        color: bulletColor,
        maxLines: 5,
      );
    }

    final donut = SizedBox(
      width: donutSize,
      height: donutSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: CircularProgressIndicator(
                value: complete ? 1 : ratio.clamp(0.0, 1.0),
                strokeWidth: donutStroke,
                strokeAlign: BorderSide.strokeAlignInside,
                backgroundColor: ringTrack,
                color: ringProgress,
              ),
            ),
          ),
          Text(
            '${complete ? 100 : (ratio * 100).round()}%',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: donutFontSize,
              fontWeight: FontWeight.w800,
              color: titleColor,
              height: 1,
            ),
          ),
        ],
      ),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: plainWhite ? const BorderSide(color: Color(0xFFE4E8F0)) : BorderSide.none,
    );

    return Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 3, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (current && !complete)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Text(
                        '현재작업',
                        style: TextStyle(
                          color: primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                PopupMenuButton<String>(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  iconSize: 22,
                  splashRadius: 22,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: current && !complete ? Colors.white.withValues(alpha: 0.88) : bodyColor,
                  ),
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'plan') {
                      onTap();
                    } else if (value == 'edit') {
                      onEditChecklist?.call();
                    } else if (value == 'current') {
                      onSetCurrentTask?.call();
                    } else if (value == 'decompose') {
                      onDecompose?.call();
                    } else if (value == 'delete') {
                      onDelete?.call();
                    }
                  },
                  itemBuilder: (context) {
                    final entries = <PopupMenuEntry<String>>[];
                    if (planningInteractions) {
                      if (onEditChecklist != null) {
                        entries.add(
                          const PopupMenuItem(value: 'edit', child: Text('체크리스트 수정')),
                        );
                      }
                      if (onSetCurrentTask != null && !complete) {
                        entries.add(
                          const PopupMenuItem(value: 'current', child: Text('현재 작업으로')),
                        );
                      }
                      if (onDecompose != null && !complete) {
                        entries.add(
                          const PopupMenuItem(value: 'decompose', child: Text('AI로 더 쪼개기')),
                        );
                      }
                      if (onDelete != null) {
                        entries.add(
                          const PopupMenuItem(value: 'delete', child: Text('삭제')),
                        );
                      }
                    } else {
                      entries.add(
                        const PopupMenuItem(value: 'plan', child: Text('오늘 블록에서 편집')),
                      );
                    }
                    return entries;
                  },
                ),
              ],
            ),
          ),
          InkWell(
            onTap: planningInteractions ? null : onTap,
            borderRadius: BorderRadius.circular(26),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 8, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          block.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (onSparkle != null) ...[
                        const SizedBox(width: 2),
                        IconButton(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          onPressed: onSparkle,
                          icon: Icon(
                            Icons.auto_awesome,
                            size: 20,
                            color: current && !complete
                                ? Colors.white.withValues(alpha: 0.92)
                                : bodyColor.withValues(alpha: 0.92),
                          ),
                          tooltip: 'AI',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (wideLayout)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: listSection()),
                        const SizedBox(width: 10),
                        donut,
                      ],
                    )
                  else ...[
                    listSection(),
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.bottomRight, child: donut),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveUnitList extends StatelessWidget {
  const _InteractiveUnitList({
    required this.units,
    required this.color,
    required this.accentBlue,
    required this.maxLines,
    required this.darkCard,
    required this.onToggle,
  });

  final List<TaskUnit> units;
  final Color color;
  final Color accentBlue;
  final int maxLines;
  final bool darkCard;
  final void Function(String unitId, bool done) onToggle;

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) {
      return Text(
        '단계를 추가해 보세요',
        style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 12),
      );
    }

    final iconTodo = darkCard ? Colors.white.withValues(alpha: 0.35) : color.withValues(alpha: 0.35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < units.length && i < maxLines; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == units.length - 1 || i == maxLines - 1 ? 0 : 3),
            child: InkWell(
              onTap: () => onToggle(units[i].id, !units[i].isDone),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        units[i].isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 20,
                        color: units[i].isDone ? accentBlue : iconTodo,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        units[i].title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          height: 1.28,
                          fontWeight: FontWeight.w500,
                          decoration: units[i].isDone ? TextDecoration.lineThrough : null,
                          decorationColor: color.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 완료 카드 — 단계를 처음부터 체크 아이콘으로 표시 (탭 불필요).
class _CompletedUnitCheckList extends StatelessWidget {
  const _CompletedUnitCheckList({
    required this.units,
    required this.textColor,
    required this.checkColor,
    required this.maxLines,
  });

  final List<TaskUnit> units;
  final Color textColor;
  final Color checkColor;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) {
      return Text(
        '단계를 추가해 보세요',
        style: TextStyle(color: textColor.withValues(alpha: 0.85), fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < units.length && i < maxLines; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == units.length - 1 || i == maxLines - 1 ? 0 : 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: checkColor.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    units[i].title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      height: 1.28,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: textColor.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _UnitBulletList extends StatelessWidget {
  const _UnitBulletList({
    required this.units,
    required this.color,
    required this.maxLines,
  });

  final List<TaskUnit> units;
  final Color color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) {
      return Text(
        '단계를 추가해 보세요',
        style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < units.length && i < maxLines; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == units.length - 1 || i == maxLines - 1 ? 0 : 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.78), shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    units[i].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 13, height: 1.28, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
