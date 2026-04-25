import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_config.dart';
import '../../ai_agent/presentation/ai_assistant_hub.dart';
import '../../gamification/presentation/gamification_providers.dart';
import '../../user_state/presentation/user_context_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../goals/presentation/goals_providers.dart';
import '../../notifications/presentation/notification_providers.dart';
import 'widgets/daily_reminder_card.dart';
import 'widgets/xp_strip.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playerProgressProvider);
    final ctx = ref.watch(userLifeContextProvider);
    final lowEnergy = ctx.sleepHours < 6 || ctx.stressLevel >= 4;
    final asyncGoals = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusFlow'),
        actions: [
          if (kApiBaseUrlConfigured)
            IconButton(
              tooltip: '로그아웃',
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '지금은 “다음 한 단계”만.',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '계획 강도 ×${ctx.planIntensityMultiplier.toStringAsFixed(2)} · 수면 ${ctx.sleepHours.toStringAsFixed(1)}h · 스트레스 ${ctx.stressLevel}/5',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (lowEnergy)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '컨디션이 낮은 날이에요. 오늘은 5분부터 시작해도 충분해요.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          if (lowEnergy) const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push('/focus'),
            icon: const Icon(Icons.timer_outlined),
            label: Text(lowEnergy ? '딱 5분만 시작' : '집중 시작'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/plan'),
            icon: const Icon(Icons.view_agenda_outlined),
            label: const Text('오늘 블록 (최대 3개)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push('/context'),
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('오늘 상태 조정'),
          ),
          const SizedBox(height: 18),
          XpStrip(progress: progress),
          const SizedBox(height: 12),
          const DailyReminderCard(),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('더 보기'),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              ListTile(
                leading: const Icon(Icons.query_stats_outlined),
                title: const Text('기록/통계'),
                onTap: () => context.push('/insights'),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('프로필'),
                subtitle: const Text('로그인/닉네임/레벨'),
                onTap: () => context.push('/profile'),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('목표'),
                subtitle: Text(
                  asyncGoals.when(
                    data: (g) => g.isEmpty ? '아직 없음' : '${g.length}개',
                    loading: () => '불러오는 중…',
                    error: (_, __) => '불러오기 실패',
                  ),
                ),
                onTap: () => context.push('/goals'),
              ),
              ListTile(
                leading: const Icon(Icons.people_alt_outlined),
                title: const Text('바디 더블링'),
                subtitle: const Text('혼자 하기 어렵다면 같이 시작'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('AI: 오늘 계획 제안'),
                onTap: () => openAiTodayPlanProposal(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.insights_outlined),
                title: const Text('AI: 실패 패턴 해석'),
                onTap: () => openAiFailurePatternConsulting(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.smart_toy_outlined),
                title: const Text('AI 도우미 (전체)'),
                subtitle: const Text('계획·패턴·쪼개기·코치 한곳에서'),
                onTap: () => showAiAssistantHub(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.hub_outlined),
                title: const Text('외부 도구 (MCP 데모)'),
                onTap: () => context.push('/mcp'),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('리마인더 테스트(로컬)'),
                onTap: () => showTestReminder(ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
