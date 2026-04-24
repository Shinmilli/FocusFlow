import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_config.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../coach/data/coach_nudge_prefs.dart';
import '../../coach/presentation/coach_nudge_controller.dart';
import '../../coach/presentation/coach_nudge_providers.dart';
import '../../gamification/presentation/gamification_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nickCtrl = TextEditingController();
  bool _init = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nickCtrl.dispose();
    super.dispose();
  }

  void _ensureInit(AuthState auth) {
    if (_init) return;
    if (auth.user != null) {
      _nickCtrl.text = auth.user!.nickname;
    }
    _init = true;
  }

  Future<void> _saveNickname() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).updateNickname(_nickCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장했어요')));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final progress = ref.watch(playerProgressProvider);
    final intensity = ref.watch(coachNudgeIntensityProvider);

    _ensureInit(auth);

    final signedIn = auth.phase == AuthPhase.authenticated && auth.user != null;

    return Scaffold(
      appBar: AppBar(title: const Text('프로필')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('레벨', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text('Lv. ${progress.level} · XP ${progress.xp}'),
                  const SizedBox(height: 8),
                  Text('스트릭 ${progress.streakDays}일 · 누적 완료 ${progress.totalBlocksCompleted}블록'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('기능', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _FeatureIcon(
                        icon: Icons.add_circle_outline,
                        label: '새 블록',
                        onTap: () => context.push('/plan/add'),
                      ),
                      _FeatureIcon(
                        icon: Icons.query_stats_outlined,
                        label: '통계',
                        onTap: () => context.push('/insights'),
                      ),
                      _FeatureIcon(
                        icon: Icons.flag_outlined,
                        label: '목표',
                        onTap: () => context.push('/goals'),
                      ),
                      _FeatureIcon(
                        icon: Icons.hub_outlined,
                        label: 'MCP',
                        onTap: () => context.push('/mcp'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _FeatureIcon(
                        icon: Icons.timeline_outlined,
                        label: '트랙',
                        onTap: () => context.push('/flow-track'),
                      ),
                      _FeatureIcon(
                        icon: Icons.auto_awesome,
                        label: 'AI 계획',
                        onTap: () => showCoachNudgeIfAny(context: context, ref: ref),
                      ),
                      _FeatureIcon(
                        icon: Icons.people_alt_outlined,
                        label: '바디더블링',
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          builder: (c) => Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('바디 더블링', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                const Text('혼자 하기 어렵다면 “딱 5분만” 같이 시작해요.'),
                                const SizedBox(height: 14),
                                FilledButton.icon(
                                  onPressed: () {
                                    Navigator.pop(c);
                                    context.push('/focus');
                                  },
                                  icon: const Icon(Icons.timer_outlined),
                                  label: const Text('5분만 시작하기'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text('닫기'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _FeatureIcon(
                        icon: Icons.timer_outlined,
                        label: '집중',
                        onTap: () => context.push('/focus'),
                      ),
                      _FeatureIcon(
                        icon: Icons.tune,
                        label: '상태',
                        onTap: () => context.push('/context'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('계정', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (!kApiBaseUrlConfigured)
                    const Text('현재는 API_BASE_URL이 없어 로컬 모드로 동작 중이에요.')
                  else if (!signedIn) ...[
                    const Text('로그인하면 닉네임을 저장하고 여러 기기에서 이어갈 수 있어요.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('로그인'),
                    ),
                  ] else ...[
                    Text(auth.user!.email, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nickCtrl,
                      maxLength: 24,
                      decoration: const InputDecoration(
                        labelText: '닉네임',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saving ? null : _saveNickname,
                      child: Text(_saving ? '저장 중…' : '닉네임 저장'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(authControllerProvider.notifier).logout();
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('로그아웃했어요')),
                        );
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('로그아웃'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('자동 제안', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  intensity.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('$e'),
                    data: (v) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              // Quick “quiet mode”: hide all nudges for today.
                              await ref.read(coachNudgePrefsProvider).hideForDays(CoachNudgeType.aiTodayPlan, 1);
                              await ref.read(coachNudgePrefsProvider).hideForDays(CoachNudgeType.bodyDoubling, 1);
                              await ref.read(coachNudgePrefsProvider).hideForDays(CoachNudgeType.insightsSummary, 1);
                              await ref.read(coachNudgePrefsProvider).hideForDays(CoachNudgeType.failurePattern, 1);
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('오늘은 자동 제안을 쉬어갈게요')),
                              );
                            },
                            child: const Text('오늘은 그만 보기'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

