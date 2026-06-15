import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../mcp/presentation/mcp_organize_flow.dart';
import '../../coach/presentation/coach_nudge_controller.dart';
import 'ai_assistant_hub.dart';

/// 홈 데스크톱 우측에 표시하는 AI 도우미 목록.
class AiAssistantPanel extends ConsumerWidget {
  const AiAssistantPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <_AiItem>[
      _AiItem(
        icon: Icons.auto_awesome,
        title: '오늘 계획 제안',
        subtitle: '목표·오늘 블록·백로그 기반 추천',
        onTap: () => openAiTodayPlanProposal(context, ref),
      ),
      _AiItem(
        icon: Icons.cloud_sync_outlined,
        title: '외부 일정 · 할 일 정리',
        subtitle: 'Notion·Google·캘린더 → AI 정리',
        onTap: () => openMcpOrganizeFlow(context, ref),
      ),
      _AiItem(
        icon: Icons.psychology_outlined,
        title: '실패 패턴 해석',
        subtitle: '미루기·이탈 신호 컨설팅',
        onTap: () => openAiFailurePatternConsulting(context, ref),
      ),
      _AiItem(
        icon: Icons.splitscreen_outlined,
        title: '큰 일을 작은 단계로',
        subtitle: '새 블록에서 AI 체크리스트',
        onTap: () => context.push('/plan/add'),
      ),
      _AiItem(
        icon: Icons.lightbulb_outline,
        title: '상황 맞춤 코치 한마디',
        subtitle: '지금 띄울 만한 자동 제안',
        onTap: () => showCoachNudgeIfAny(context: context, ref: ref),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          _AiTile(item: items[i]),
        ],
      ],
    );
  }
}

class _AiItem {
  const _AiItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _AiTile extends StatelessWidget {
  const _AiTile({required this.item});

  final _AiItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, size: 20, color: const Color(0xFF4A90E2)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1C26),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8E93A3),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
