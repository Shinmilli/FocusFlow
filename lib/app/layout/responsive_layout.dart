import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 모바일(너비 <760) vs 노트북·데스크톱(≥760) 구분.
abstract final class ResponsiveLayout {
  static const double compactBreakpoint = 760;

  /// 뷰포트 너비 (MediaQuery).
  static double effectiveWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// 레이아웃 분기용 너비 — 부모가 과대 제약을 줄 때 더 좁은 값을 신뢰한다.
  static double layoutWidth(BuildContext context, [BoxConstraints? constraints]) {
    final viewport = effectiveWidth(context);
    if (constraints == null || !constraints.hasBoundedWidth) return viewport;
    return math.min(viewport, constraints.maxWidth);
  }

  static bool isCompact(BuildContext context) =>
      effectiveWidth(context) < compactBreakpoint;

  static bool isExpanded(BuildContext context) => !isCompact(context);

  static bool isCompactForLayout(BuildContext context, [BoxConstraints? constraints]) =>
      layoutWidth(context, constraints) < compactBreakpoint;

  static bool isExpandedForLayout(BuildContext context, [BoxConstraints? constraints]) =>
      !isCompactForLayout(context, constraints);

  static bool isCompactConstraints(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth) return true;
    return constraints.maxWidth < compactBreakpoint;
  }

  static bool isExpandedConstraints(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth) return false;
    return constraints.maxWidth >= compactBreakpoint;
  }

  static bool useExpandedLayout(BuildContext context, BoxConstraints constraints) {
    final expanded = isExpandedForLayout(context, constraints);
    assert(() {
      if (constraints.hasBoundedWidth &&
          isExpandedConstraints(constraints) != expanded) {
        logDiagnostics(context, tag: 'mismatch', constraints: constraints);
      }
      return true;
    }());
    return expanded;
  }

  /// 디버그 콘솔에서 레이아웃 분기 값 확인용 (릴리스 빌드에서는 no-op).
  static void logDiagnostics(
    BuildContext context, {
    String tag = 'layout',
    BoxConstraints? constraints,
  }) {
    assert(() {
      final mq = MediaQuery.sizeOf(context);
      final view = View.of(context);
      final physical = view.physicalSize.width / view.devicePixelRatio;
      final constraintW = constraints == null
          ? null
          : constraints.hasBoundedWidth
              ? constraints.maxWidth
              : double.infinity;
      debugPrint(
        '[FocusFlow:$tag] '
        'mq=${mq.width.toStringAsFixed(1)} '
        'physical=${physical.toStringAsFixed(1)} '
        'layout=${layoutWidth(context, constraints).toStringAsFixed(1)} '
        'compact=${isCompactForLayout(context, constraints)} '
        'constraints=${constraintW == null ? 'n/a' : constraintW == double.infinity ? '∞' : constraintW.toStringAsFixed(1)}',
      );
      return true;
    }());
  }
}
