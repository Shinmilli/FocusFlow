import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/desktop_panel_card.dart';
import '../../../ai_agent/presentation/ai_assistant_panel.dart';
import '../../../user_state/presentation/user_context_panel.dart';

/// 홈 화면 데스크톱 우측 — AI 도우미 + 오늘 상태 (가용 너비에 맞춰 확장).
class HomeDesktopSidePanel extends ConsumerWidget {
  const HomeDesktopSidePanel({super.key});

  static const minWidth = 280.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopPanelCard(
            title: 'AI 도우미',
            child: const AiAssistantPanel(),
          ),
          const SizedBox(height: 14),
          DesktopPanelCard(
            title: '오늘 상태',
            child: UserContextPanel(compact: true),
          ),
        ],
      ),
    );
  }
}
