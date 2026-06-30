import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../router/shell_layout.dart';

/// 모바일(너비 <760) vs 노트북·데스크톱(≥760) 구분.
abstract final class ResponsiveLayout {
  static const double compactBreakpoint = 760;

  static double effectiveWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// 레이아웃 분기용 너비 — 부모가 과대 제약을 줄 때 더 좁은 값을 사용.
  static double layoutWidth(BuildContext context, [BoxConstraints? constraints]) {
    final viewport = effectiveWidth(context);
    if (constraints == null || !constraints.hasBoundedWidth) return viewport;
    return math.min(viewport, constraints.maxWidth);
  }

  static bool isCompact(BuildContext context) {
    if (ShellLayoutScope.isCompactShell(context)) return true;
    return effectiveWidth(context) < compactBreakpoint;
  }

  static bool isExpanded(BuildContext context) => !isCompact(context);

  static bool isCompactForLayout(BuildContext context, [BoxConstraints? constraints]) {
    if (ShellLayoutScope.isCompactShell(context)) return true;
    return layoutWidth(context, constraints) < compactBreakpoint;
  }

  static bool useExpandedLayout(BuildContext context, BoxConstraints constraints) =>
      !ShellLayoutScope.isCompactShell(context) &&
      layoutWidth(context, constraints) >= compactBreakpoint;
}
