import 'package:flutter/material.dart';

/// 모바일(너비 <760) vs 노트북·데스크톱(≥760) 구분.
abstract final class ResponsiveLayout {
  static const double compactBreakpoint = 760;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactBreakpoint;

  static bool isExpanded(BuildContext context) => !isCompact(context);
}
