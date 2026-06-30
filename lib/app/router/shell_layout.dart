import 'package:flutter/material.dart';

/// 메인 셸(하단 네비 vs 사이드바) 모드 — 하위 화면 레이아웃 분기 기준.
class ShellLayoutScope extends InheritedWidget {
  const ShellLayoutScope({
    super.key,
    required this.compact,
    required super.child,
  });

  final bool compact;

  static bool isCompactShell(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellLayoutScope>()?.compact ??
      false;

  @override
  bool updateShouldNotify(ShellLayoutScope oldWidget) =>
      compact != oldWidget.compact;
}
