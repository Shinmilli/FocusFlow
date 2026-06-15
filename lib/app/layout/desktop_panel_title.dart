import 'package:flutter/material.dart';

import '../theme/app_chrome.dart';

/// 데스크톱·노트북 패널 상단 — 배경 없이 남색 제목.
class DesktopPanelTitleRow extends StatelessWidget {
  const DesktopPanelTitleRow({
    super.key,
    required this.title,
    this.trailing,
    this.centerTitle = false,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 12, 10),
  });

  final String title;
  final Widget? trailing;
  final bool centerTitle;
  final EdgeInsets padding;

  static const TextStyle titleStyle = TextStyle(
    color: AppChrome.primaryActionNavy,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.2,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              textAlign: centerTitle ? TextAlign.center : TextAlign.start,
              style: titleStyle,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
