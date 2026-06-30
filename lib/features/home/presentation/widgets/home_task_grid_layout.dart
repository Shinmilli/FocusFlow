import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/layout/responsive_layout.dart';
import 'home_desktop_side_panel.dart';

/// 홈 할 일 그리드 — 모바일 2열 카드보다 좁아지지 않도록 열 수 결정.
abstract final class HomeTaskGridLayout {
  static const compactCrossCount = 2;
  static const maxExpandedCrossCount = 3;
  static const gridPaddingCompact = 16.0;
  static const gridPaddingExpanded = 12.0;
  static const gridSpacing = 14.0;
  static const navRailWidth = 72.0;

  /// 일반적인 최소 모바일 뷰포트(360)에서 2열일 때 카드 너비.
  static const minMobileViewport = 360.0;

  static double get minMobileCardWidth =>
      (minMobileViewport - gridPaddingCompact * 2 - gridSpacing) / compactCrossCount;

  /// 카드 내부 가로(도넛+리스트) 레이아웃 전환 기준.
  static const wideCardMinWidth = 280.0;

  static double homeMainColumnWidth(double viewportWidth) {
    if (viewportWidth < ResponsiveLayout.compactBreakpoint) {
      return viewportWidth;
    }
    final contentW = viewportWidth - navRailWidth;
    const mainFlex = 5;
    const sideFlex = 2;
    final sideW = math.max(
      HomeDesktopSidePanel.minWidth,
      contentW * sideFlex / (mainFlex + sideFlex),
    );
    return contentW - sideW;
  }

  static int crossAxisCountForWidth(double viewportWidth) {
    if (viewportWidth < ResponsiveLayout.compactBreakpoint) return compactCrossCount;

    final mainW = homeMainColumnWidth(viewportWidth);
    final pad = gridPaddingExpanded * 2;
    final minCard = minMobileCardWidth;

    for (var cols = maxExpandedCrossCount; cols >= compactCrossCount; cols--) {
      final cardW = (mainW - pad - gridSpacing * (cols - 1)) / cols;
      if (cardW >= minCard) return cols;
    }
    return compactCrossCount;
  }

  static int crossAxisCount(BuildContext context) {
    if (ResponsiveLayout.isCompact(context)) return compactCrossCount;

    final mainW = homeMainColumnWidth(ResponsiveLayout.effectiveWidth(context));
    final pad = gridPaddingExpanded * 2;
    final minCard = minMobileCardWidth;

    for (var cols = maxExpandedCrossCount; cols >= compactCrossCount; cols--) {
      final cardW = (mainW - pad - gridSpacing * (cols - 1)) / cols;
      if (cardW >= minCard) return cols;
    }
    return compactCrossCount;
  }

  static double gridHorizontalPadding(BuildContext context) =>
      ResponsiveLayout.isExpanded(context) ? gridPaddingExpanded : gridPaddingCompact;
}
