import 'package:flutter/material.dart';

import '../theme/app_chrome.dart';
import 'desktop_panel_title.dart';

/// 데스크톱 우측 패널용 — 둥근 카드 + 남색 제목(배경 없음).
class DesktopPanelCard extends StatelessWidget {
  const DesktopPanelCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppChrome.softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DesktopPanelTitleRow(title: title, trailing: trailing),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}
