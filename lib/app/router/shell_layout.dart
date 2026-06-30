import 'package:flutter/material.dart';

/// 노트북·데스크톱 셸 본문 슬롯 (모바일은 Column+Expanded 사용).
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
