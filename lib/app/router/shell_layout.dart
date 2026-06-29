import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// IndexedStack이 셸 본문 영역을 꽉 채우도록 (모바일 웹 높이 0 방지).
Widget shellIndexedStackContainer(
  BuildContext context,
  StatefulNavigationShell navigationShell,
  List<Widget> children,
) {
  return IndexedStack(
    index: navigationShell.currentIndex,
    sizing: StackFit.expand,
    children: children,
  );
}

/// Scaffold body 안에서 navigationShell에 명시적 높이 전달.
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
