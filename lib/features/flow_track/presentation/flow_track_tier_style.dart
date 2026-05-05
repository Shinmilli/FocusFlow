import 'package:flutter/material.dart';

/// 플로우 트랙 티어(Iron~Mythic)별 직관적인 색.
abstract final class FlowTrackTierStyle {
  FlowTrackTierStyle._();

  static Color accent(String tierEn) {
    return switch (tierEn) {
      'Iron' => const Color(0xFF57534E),
      'Bronze' => const Color(0xFFC2410C),
      'Silver' => const Color(0xFF94A3B8),
      'Gold' => const Color(0xFFD97706),
      'Platinum' => const Color(0xFF475569),
      'Sapphire' => const Color(0xFF1D4ED8),
      'Ruby' => const Color(0xFFDC2626),
      'Diamond' => const Color(0xFF0E7490),
      'Mythic' => const Color(0xFF9333EA),
      _ => const Color(0xFF57534E),
    };
  }

  /// [accent] 배경(또는 칩) 위 대비되는 글자색.
  static Color onAccent(Color bg) {
    final y = bg.computeLuminance();
    return y > 0.42 ? const Color(0xFF12121A) : Colors.white;
  }

  static Color subtitleOnAccent(Color bg) {
    final fg = onAccent(bg);
    return fg.computeLuminance() > 0.5
        ? const Color(0xFF12121A).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.88);
  }

  static Color cardTint(String tierEn) => accent(tierEn).withValues(alpha: 0.08);
}
