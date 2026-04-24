import 'package:flutter/material.dart';

import '../../../gamification/domain/player_progress.dart';

class XpStrip extends StatelessWidget {
  const XpStrip({super.key, required this.progress});

  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final need = PlayerProgress.xpForLevel(progress.level);
    final ratio = need == 0 ? 0.0 : progress.xp / need;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lv.${progress.level} · 스트릭 ${progress.streakDays}일'),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'XP ${progress.xp} / $need',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (progress.badges.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('배지', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final b in progress.badges.take(8))
                Chip(
                  label: Text(b, style: Theme.of(context).textTheme.labelSmall),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

