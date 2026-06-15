import 'package:flutter/material.dart';

import 'desktop_panel_title.dart';

/// 프로필 데스크톱 우측 패널 — 둥근 카드 안에 남색 제목(배경 없음).
class EmbeddedScreenShell extends StatelessWidget {
  const EmbeddedScreenShell({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  static const Color panelBackground = Color(0xFFF7F8FB);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: panelBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopPanelTitleRow(
            title: title,
            trailing: actions.isEmpty
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
