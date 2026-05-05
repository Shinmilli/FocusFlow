import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_router.dart';
import '../domain/player_progress.dart';

final celebrationCoordinatorProvider = Provider<CelebrationCoordinator>((ref) {
  return CelebrationCoordinator();
});

/// 레벨업·배지 해금 시 루트 네비게이터로 축하 다이얼로그 표시.
class CelebrationCoordinator {
  void onProgressGained(PlayerProgress prev, PlayerProgress next) {
    final levelUp = next.level > prev.level;
    final prevB = prev.badges.toSet();
    final newBadges = next.badges.where((b) => !prevB.contains(b)).toList();

    if (!levelUp && newBadges.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      final lines = <String>[];
      if (levelUp) {
        lines.add('레벨 ${prev.level} → ${next.level} 달성!');
      }
      for (final b in newBadges) {
        lines.add('배지: $b');
      }

      showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(Icons.celebration_rounded, size: 44, color: Theme.of(ctx).colorScheme.primary),
          title: const Text('축하해요!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines) ...[
                Text(line, style: Theme.of(ctx).textTheme.bodyLarge),
                const SizedBox(height: 6),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('좋아요'),
            ),
          ],
        ),
      );
    });
  }
}
