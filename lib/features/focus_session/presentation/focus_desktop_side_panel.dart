import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout/desktop_panel_card.dart';
import '../../../app/theme/app_chrome.dart';
import '../../planning/domain/task_block.dart';
import 'widgets/focus_checklist_panel.dart';
import 'widgets/parked_thoughts_card.dart';

/// 집중 모드 데스크톱 우측 — 할 일 · 딴생각 · AI.
class FocusDesktopSidePanel extends ConsumerWidget {
  const FocusDesktopSidePanel({
    super.key,
    required this.blocks,
    required this.taskLookupNotLeave,
    required this.onTaskLookupChanged,
    required this.onNudge,
    this.lookupToggleEnabled = true,
  });

  static const width = 300.0;

  final List<TaskBlock> blocks;
  final bool taskLookupNotLeave;
  final ValueChanged<bool> onTaskLookupChanged;
  final VoidCallback onNudge;
  final bool lookupToggleEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: width,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: AppChrome.softCardDecoration(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        '이탈이 아니라 자료찾기 중이에요!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF2C3140),
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                      ),
                    ),
                    Switch.adaptive(
                      value: taskLookupNotLeave,
                      onChanged: lookupToggleEnabled ? onTaskLookupChanged : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FocusChecklistPanel(blocks: blocks, embedded: true),
            const SizedBox(height: 14),
            DesktopPanelCard(
              title: '딴생각 목록',
              child: const ParkedThoughtsCard(embedded: true),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onNudge,
              icon: const Icon(Icons.psychology_alt_outlined),
              label: const Text('딴생각 정리 (AI)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2C3140),
                side: const BorderSide(color: AppChrome.softBorder),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
