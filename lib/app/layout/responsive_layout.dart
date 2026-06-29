import 'package:flutter/material.dart';

/// 모바일(짧은 변 <760) vs 노트북·데스크톱(≥760) 구분.
abstract final class ResponsiveLayout {
  static const double compactBreakpoint = 760;

  static bool isCompact(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // 가로 모드·웹 뷰포트 오류에도 폰은 모바일 레이아웃 유지.
    return size.shortestSide < compactBreakpoint;
  }

  static bool isExpanded(BuildContext context) => !isCompact(context);
}
