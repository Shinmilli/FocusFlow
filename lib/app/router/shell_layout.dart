import 'package:flutter/material.dart';

/// 메인 셸(하단 네비 vs 사이드바) 모드 — 하위 화면이 동일 기준으로 레이아웃 분기.
class ShellLayoutScope extends InheritedWidget {
  const ShellLayoutScope({
    super.key,
    required this.compact,
    required super.child,
  });

  final bool compact;

  static ShellLayoutScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellLayoutScope>();
  }

  static bool isCompactShell(BuildContext context) =>
      maybeOf(context)?.compact ?? false;

  @override
  bool updateShouldNotify(ShellLayoutScope oldWidget) =>
      compact != oldWidget.compact;
}

/// 셸 본문 슬롯 — navigationShell에 명시적 너비·높이 제약 전달.
class ShellBodySlot extends StatelessWidget {
  const ShellBodySlot({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: child,
        );
      },
    );
  }
}
