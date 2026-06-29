import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 셸 탭 본문이 높이 0이 되지 않도록 IndexedStack을 화면 전체로 확장.
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

/// StatefulShellRoute 브랜치 화면이 항상 남는 공간을 채우도록 래핑.
class ShellTabBody extends StatelessWidget {
  const ShellTabBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F6FA),
      child: SizedBox.expand(child: child),
    );
  }
}
