import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/desktop_panel_card.dart';
import '../../ai_agent/presentation/ai_assistant_panel.dart';
import '../../coach/data/coach_nudge_prefs.dart';
import '../../coach/presentation/coach_nudge_providers.dart';
import '../../flow_track/presentation/flow_track_screen.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../insights/presentation/insights_screen.dart';
import '../../mcp/presentation/mcp_connections_screen.dart';
import '../../user_state/presentation/user_context_panel.dart';

enum ProfileDetailSection {
  track,
  stats,
  goals,
  mcp,
  ai,
  bodyDoubling,
  context,
  suggestions,
}

extension ProfileDetailSectionX on ProfileDetailSection {
  String get title => switch (this) {
        ProfileDetailSection.track => '플로우 트랙',
        ProfileDetailSection.stats => '기록/통계',
        ProfileDetailSection.goals => '목표',
        ProfileDetailSection.mcp => '외부 연결',
        ProfileDetailSection.ai => 'AI 도우미',
        ProfileDetailSection.bodyDoubling => '바디 더블링',
        ProfileDetailSection.context => '오늘 상태',
        ProfileDetailSection.suggestions => '자동 제안',
      };
}

/// 프로필 데스크톱 우측 상세 패널.
class ProfileDetailPanel extends ConsumerWidget {
  const ProfileDetailPanel({
    super.key,
    required this.section,
  });

  final ProfileDetailSection section;

  static BoxDecoration _embeddedDecoration() {
    return BoxDecoration(
      color: const Color(0xFFF7F8FB),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE4E8F0)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final embeddedChild = switch (section) {
      ProfileDetailSection.track => const FlowTrackScreen(embedded: true),
      ProfileDetailSection.stats => const InsightsScreen(embedded: true),
      ProfileDetailSection.goals => const GoalsScreen(embedded: true),
      ProfileDetailSection.mcp => const McpConnectionsScreen(embedded: true),
      _ => null,
    };

    if (embeddedChild != null) {
      return DecoratedBox(
        decoration: _embeddedDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox.expand(child: embeddedChild),
        ),
      );
    }

    return DesktopPanelCard(
      title: section.title,
      child: SingleChildScrollView(
        child: _ProfileDetailBody(section: section),
      ),
    );
  }
}

class _ProfileDetailBody extends ConsumerWidget {
  const _ProfileDetailBody({required this.section});

  final ProfileDetailSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (section) {
      case ProfileDetailSection.track:
      case ProfileDetailSection.stats:
      case ProfileDetailSection.goals:
      case ProfileDetailSection.mcp:
        return const SizedBox.shrink();
      case ProfileDetailSection.ai:
        return const AiAssistantPanel();
      case ProfileDetailSection.bodyDoubling:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('혼자 하기 어렵다면 “딱 5분만” 같이 시작해요.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/focus'),
              icon: const Icon(Icons.timer_outlined),
              label: const Text('5분만 시작하기'),
            ),
          ],
        );
      case ProfileDetailSection.context:
        return const UserContextPanel(compact: true);
      case ProfileDetailSection.suggestions:
        return const _SuggestionsPanel();
    }
  }
}

class _SuggestionsPanel extends ConsumerWidget {
  const _SuggestionsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intensity = ref.watch(coachNudgeIntensityProvider);

    return intensity.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (v) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('적극적으로 제안 받기'),
              subtitle: Text(v == CoachNudgeIntensity.active ? '상황별로 더 자주' : '하루 1~2번만'),
              value: v == CoachNudgeIntensity.active,
              onChanged: (on) async {
                final next = on ? CoachNudgeIntensity.active : CoachNudgeIntensity.light;
                await ref.read(coachNudgePrefsProvider).setIntensity(next);
                ref.invalidate(coachNudgeIntensityProvider);
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await ref.read(coachNudgePrefsProvider).hideForDays(CoachNudgeType.aiTodayPlan, 1);
                await ref.read(coachNudgePrefsProvider).hideForDays(CoachNudgeType.bodyDoubling, 1);
                await ref.read(coachNudgePrefsProvider).hideForDays(CoachNudgeType.insightsSummary, 1);
                await ref.read(coachNudgePrefsProvider).hideForDays(CoachNudgeType.failurePattern, 1);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('오늘은 자동 제안을 쉬어갈게요')),
                );
              },
              child: const Text('오늘은 그만 보기'),
            ),
          ],
        );
      },
    );
  }
}
