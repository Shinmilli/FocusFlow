import 'package:flutter/material.dart';

/// 홈 히어로·셸과 맞춘 공통 표면/색.
abstract final class AppChrome {
  static const Color pageBackground = Color(0xFFF5F6FA);
  static const Color heroCardDark = Color(0xFF1F212A);
  static const Color heroBadgeBg = Color(0xFF2E3548);
  static const Color heroMuted = Color(0xFFB8BCC8);
  static const Color heroAccentBlue = Color(0xFF4A7DFF);
  /// 홈·사이드바 버튼과 맞춘 밝은 파랑.
  static const Color navPrimaryBlue = Color(0xFF4A90E2);
  static const Color softBorder = Color(0xFFE4E8F0);

  /// 완료·저장·강제시작 등 공통 (남색, 굵지 않은 라벨).
  static const Color primaryActionNavy = Color(0xFF2E3548);

  /// 집중 모드·이번 주 조정·프로필 등 상단 앱바 (남색 배경·흰 글자).
  static const Color topBarBackground = heroCardDark;
  static const Color topBarForeground = Colors.white;

  static final ButtonStyle primaryActionNavyStyle = FilledButton.styleFrom(
    backgroundColor: primaryActionNavy,
    foregroundColor: Colors.white,
    textStyle: const TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 16,
      color: Colors.white,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    minimumSize: const Size.fromHeight(48),
  );

  static Color softCard(BuildContext context) => Colors.white;

  static BoxDecoration softCardDecoration({Color? color}) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: softBorder),
    );
  }

  /// 레벨 구간별 호칭 (프로필 헤드라인).
  static String focusPersonaTitle(int level) {
    if (level >= 20) return '집중 레전드';
    if (level >= 15) return '집중 장인';
    if (level >= 10) return '집중 숙련자';
    if (level >= 5) return '집중 도전자';
    return '집중 초보자';
  }
}
