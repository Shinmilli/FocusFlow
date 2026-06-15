import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/desktop_panel_card.dart';
import '../../../../app/theme/app_chrome.dart';
import '../../../planning/domain/task_block.dart';
import '../../../planning/domain/task_unit.dart';
import '../../../planning/presentation/planning_actions.dart';

/// 집중 모드 — 홈과 동일한 현재 작업·체크리스트.
class FocusChecklistPanel extends ConsumerWidget {
  const FocusChecklistPanel({
    super.key,
    required this.blocks,
    this.embedded = false,
  });

  final List<TaskBlock> blocks;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = resolveActiveTaskBlock(blocks);

    if (active == null || active.units.isEmpty) {
      final empty = Text(
        '오늘 블록이 없거나 단계가 없어요. 홈에서 블록을 추가해 보세요.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B7080),
            ),
      );
      if (embedded) {
        return DesktopPanelCard(title: '지금 할 일', child: empty);
      }
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: AppChrome.softCardDecoration(),
        child: empty,
      );
    }

    final primary = Theme.of(context).colorScheme.primary;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded)
          Text(
            '지금 할 일',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppChrome.navPrimaryBlue,
                  fontWeight: FontWeight.w800,
                ),
          ),
        if (!embedded) const SizedBox(height: 6),
        Text(
          active.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF2C3140),
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
        ),
        const SizedBox(height: 8),
        _FocusInteractiveUnitList(
          units: active.units,
          accentBlue: primary,
          onToggle: (unitId, done) => toggleTaskUnitDone(
            ref: ref,
            block: active,
            unitId: unitId,
            done: done,
          ),
        ),
      ],
    );

    if (embedded) {
      return DesktopPanelCard(title: '지금 할 일', child: content);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      decoration: AppChrome.softCardDecoration(),
      child: content,
    );
  }
}

class _FocusInteractiveUnitList extends StatelessWidget {
  const _FocusInteractiveUnitList({
    required this.units,
    required this.accentBlue,
    required this.onToggle,
  });

  final List<TaskUnit> units;
  final Color accentBlue;
  final Future<void> Function(String unitId, bool done) onToggle;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF2C3140);
    const iconTodo = Color(0xFF8E93A3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < units.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == units.length - 1 ? 0 : 3),
            child: InkWell(
              onTap: () => onToggle(units[i].id, !units[i].isDone),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
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
