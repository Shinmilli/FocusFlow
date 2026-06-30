import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/responsive_layout.dart';
import '../../../app/theme/app_chrome.dart';
import '../../../core/config/api_config.dart';
import '../../ai_agent/presentation/ai_assistant_hub.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../coach/data/coach_nudge_prefs.dart';
import '../../coach/presentation/coach_nudge_providers.dart';
import '../../gamification/domain/player_progress.dart';
import '../../gamification/presentation/gamification_providers.dart';
import 'profile_detail_panel.dart';

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
  ProfileDetailSection _desktopSection = ProfileDetailSection.track;

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
      await ref
          .read(authControllerProvider.notifier)
          .updateNickname(_nickCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('저장했어요')));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _buildProfile(context, constraints),
    );
  }

  Widget _buildProfile(BuildContext context, BoxConstraints constraints) {
    final auth = ref.watch(authControllerProvider);
    final progress = ref.watch(playerProgressProvider);
    final intensity = ref.watch(coachNudgeIntensityProvider);

    _ensureInit(auth);

    final signedIn = auth.phase == AuthPhase.authenticated && auth.user != null;
    final shell = StatefulNavigationShell.maybeOf(context);
    final expanded = ResponsiveLayout.isExpandedConstraints(constraints);
    final accountTitleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1A1C26),
        );

    void selectDesktopSection(ProfileDetailSection section) {
      setState(() => _desktopSection = section);
    }

    void onFeatureTap(ProfileDetailSection section, VoidCallback mobileAction) {
      if (expanded) {
        selectDesktopSection(section);
      } else {
        mobileAction();
      }
    }

    final leftContent = ListView(
      padding: EdgeInsets.fromLTRB(16, expanded ? 16 : 12, 16, 28),
      children: [
          Container(
            width: double.infinity,
            decoration: AppChrome.softCardDecoration(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!kApiBaseUrlConfigured) ...[
                  Text('계정', style: accountTitleStyle),
                  const SizedBox(height: 8),
                  const Text('현재는 API_BASE_URL이 없어 로컬 모드로 동작 중이에요.'),
                ] else if (!signedIn) ...[
                  Text('계정', style: accountTitleStyle),
                  const SizedBox(height: 8),
                  const Text('로그인하면 닉네임을 저장하고 여러 기기에서 이어갈 수 있어요.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('로그인'),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text('계정', style: accountTitleStyle),
                      ),
                      FilledButton(
                        style: AppChrome.primaryActionNavyStyle.copyWith(
                          visualDensity: VisualDensity.compact,
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _saving ? null : _saveNickname,
                        child: Text(_saving ? '저장 중…' : '닉네임 저장'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                        onPressed: () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .logout();
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('로그아웃했어요')),
                          );
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('로그아웃'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(auth.user!.email,
                      style: Theme.of(context).textTheme.bodySmall),
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
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ProfileHeroCard(
            progress: progress,
            signedIn: signedIn,
            nickname: signedIn ? auth.user!.nickname : null,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            decoration: AppChrome.softCardDecoration(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '기능',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1C26),
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _FeatureIcon(
                      icon: Icons.query_stats_outlined,
                      label: '통계',
                      selected: expanded && _desktopSection == ProfileDetailSection.stats,
                      onTap: () => onFeatureTap(
                        ProfileDetailSection.stats,
                        () => context.push('/insights'),
                      ),
                    ),
                    _FeatureIcon(
                      icon: Icons.flag_outlined,
                      label: '목표',
                      selected: expanded && _desktopSection == ProfileDetailSection.goals,
                      onTap: () => onFeatureTap(
                        ProfileDetailSection.goals,
                        () => context.push('/goals'),
                      ),
                    ),
                    _FeatureIcon(
                      icon: Icons.emoji_events_outlined,
                      label: '트랙',
                      selected: expanded && _desktopSection == ProfileDetailSection.track,
                      onTap: () => onFeatureTap(
                        ProfileDetailSection.track,
                        () => context.push('/flow-track'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _FeatureIcon(
                      icon: Icons.link,
                      label: '외부 연결',
                      selected: expanded && _desktopSection == ProfileDetailSection.mcp,
                      onTap: () => onFeatureTap(
                        ProfileDetailSection.mcp,
                        () => context.push('/mcp'),
                      ),
                    ),
                    _FeatureIcon(
                      icon: Icons.auto_awesome,
                      label: 'AI 도우미',
                      selected: expanded && _desktopSection == ProfileDetailSection.ai,
                      onTap: () => onFeatureTap(
                        ProfileDetailSection.ai,
                        () => showAiAssistantHub(context, ref),
                      ),
                    ),
                    _FeatureIcon(
                      icon: Icons.people_alt_outlined,
                      label: '바디더블링',
                      selected: expanded && _desktopSection == ProfileDetailSection.bodyDoubling,
                      onTap: () => onFeatureTap(
                        ProfileDetailSection.bodyDoubling,
                        () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          builder: (c) => Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('바디 더블링',
                                    style: Theme.of(context).textTheme.titleMedium),
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
                    ),
                    _FeatureIcon(
                      icon: Icons.health_and_safety_outlined,
                      label: '상태',
                      selected: expanded && _desktopSection == ProfileDetailSection.context,
                      onTap: () => onFeatureTap(
                        ProfileDetailSection.context,
                        () => context.push('/context'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!expanded) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: AppChrome.softCardDecoration(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '자동 제안',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1C26),
                        ),
                  ),
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
                            subtitle: Text(v == CoachNudgeIntensity.active
                                ? '상황별로 더 자주'
                                : '하루 1~2번만'),
                            value: v == CoachNudgeIntensity.active,
                            onChanged: (on) async {
                              final next = on
                                  ? CoachNudgeIntensity.active
                                  : CoachNudgeIntensity.light;
                              await ref
                                  .read(coachNudgePrefsProvider)
                                  .setIntensity(next);
                              ref.invalidate(coachNudgeIntensityProvider);
                            },
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () async {
                              await ref
                                  .read(coachNudgePrefsProvider)
                                  .hideForDays(CoachNudgeType.aiTodayPlan, 1);
                              await ref
                                  .read(coachNudgePrefsProvider)
                                  .hideForDays(CoachNudgeType.bodyDoubling, 1);
                              await ref
                                  .read(coachNudgePrefsProvider)
                                  .hideForDays(CoachNudgeType.insightsSummary, 1);
                              await ref
                                  .read(coachNudgePrefsProvider)
                                  .hideForDays(CoachNudgeType.failurePattern, 1);
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
          ] else ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: AppChrome.softCardDecoration(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '자동 제안',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1C26),
                        ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => selectDesktopSection(ProfileDetailSection.suggestions),
                    child: const Text('자동 제안 설정 열기'),
                  ),
                ],
              ),
            ),
          ],
        ],
      );

    final body = expanded
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 420,
                child: leftContent,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: ProfileDetailPanel(section: _desktopSection),
                ),
              ),
            ],
          )
        : leftContent;

    return Scaffold(
      backgroundColor: AppChrome.pageBackground,
      appBar: expanded
          ? null
          : AppBar(
              backgroundColor: AppChrome.topBarBackground,
              foregroundColor: AppChrome.topBarForeground,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              title: const Text('프로필'),
              leading: shell != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      tooltip: '오늘',
                      onPressed: () => shell.goBranch(0),
                    )
                  : null,
              automaticallyImplyLeading: shell == null,
            ),
      body: expanded ? SafeArea(child: body) : body,
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.progress,
    required this.signedIn,
    this.nickname,
  });

  final PlayerProgress progress;
  final bool signedIn;
  final String? nickname;

  @override
  Widget build(BuildContext context) {
    final persona = AppChrome.focusPersonaTitle(progress.level);
    final nick = nickname?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppChrome.heroCardDark,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppChrome.heroBadgeBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Text(
                  'Lv.${progress.level} · XP ${progress.xp}',
                  style: const TextStyle(
                    color: AppChrome.heroAccentBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              persona,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -0.4,
              ),
            ),
            if (signedIn && nick != null && nick.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                nick,
                style: TextStyle(
                  color: AppChrome.heroMuted.withValues(alpha: 0.95),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  '연속 ${progress.streakDays}일',
                  style: const TextStyle(
                    color: AppChrome.heroMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 18),
                Text(
                  '누적 ${progress.totalBlocksCompleted}블록',
                  style: const TextStyle(
                    color: AppChrome.heroMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF4A90E2) : const Color(0xFF5C6378);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: selected
              ? BoxDecoration(
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4A90E2).withValues(alpha: 0.35)),
                )
              : const BoxDecoration(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected ? const Color(0xFF4A90E2) : const Color(0xFF8E93A3),
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
