import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 모바일(너비 <760) vs 노트북·데스크톱(≥760) 구분.
abstract final class ResponsiveLayout {
  static const double compactBreakpoint = 760;

  /// 실제 표시 너비 — 모바일 웹에서 viewport 미설정 시 MediaQuery만 980px로 잡히는 문제 보정.
  static double effectiveWidth(BuildContext context) {
    final mqWidth = MediaQuery.sizeOf(context).width;
    final view = View.of(context);
    final physicalWidth = view.physicalSize.width / view.devicePixelRatio;
    return math.min(mqWidth, physicalWidth);
  }

  static bool isCompact(BuildContext context) =>
      effectiveWidth(context) < compactBreakpoint;

  static bool isExpanded(BuildContext context) => !isCompact(context);

  static bool isCompactConstraints(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth) return true;
    return constraints.maxWidth < compactBreakpoint;
  }

  static bool isExpandedConstraints(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth) return false;
    return constraints.maxWidth >= compactBreakpoint;
  }

  /// LayoutBuilder + 뷰포트 — 본문 너비가 무한일 때(셸·스크롤) MediaQuery로 보정.
  static bool useExpandedLayout(BuildContext context, BoxConstraints constraints) {
    if (constraints.hasBoundedWidth) {
      return isExpandedConstraints(constraints);
    }
    return isExpanded(context);
  }
}
