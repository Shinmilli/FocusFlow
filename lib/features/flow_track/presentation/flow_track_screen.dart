import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_chrome.dart';
import '../../gamification/domain/badge_catalog.dart';
import '../../gamification/domain/player_progress.dart';
import '../../gamification/presentation/gamification_providers.dart';
import '../data/flow_track_repository.dart';
import '../domain/flow_week_segment.dart';
import 'flow_track_achievements_sheet.dart';
import 'flow_track_providers.dart';
import 'flow_track_tier_style.dart';

/// ISO 주 시작일(월요일, `yyyy-MM-dd`) → 사용자에게 보여 줄 한글 구간.
String _flowWeekRangeLabelKo(String weekStartDateKey) {
  final parts = weekStartDateKey.split('-');
  if (parts.length != 3) return weekStartDateKey;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return weekStartDateKey;
  final start = DateTime(y, m, d);
  final end = start.add(const Duration(days: 6));

  String md(DateTime dt) => '${dt.month}월 ${dt.day}일';

  if (start.year == end.year && start.month == end.month) {
    return '$y년 ${start.month}월 ${start.day}일 ~ ${end.day}일';
  }
  if (start.year == end.year) {
    return '$y년 ${md(start)} ~ ${md(end)}';
  }
  return '${start.year}년 ${md(start)} ~ ${end.year}년 ${md(end)}';
}

/// 플로우 트랙 — 상단 트랙/배지 전환, 현재 티어 표시.
class FlowTrackScreen extends ConsumerStatefulWidget {
  const FlowTrackScreen({super.key});

  @override
  ConsumerState<FlowTrackScreen> createState() => _FlowTrackScreenState();
}

class _FlowTrackScreenState extends ConsumerState<FlowTrackScreen> {
  int _tab = 0;

  static const _lineColor = Color(0xFF111111);

  static int _tierLevel(String tier) {
    const order = ['Iron', 'Bronze', 'Silver', 'Gold', 'Platinum', 'Sapphire', 'Ruby', 'Diamond', 'Mythic'];
    final i = order.indexOf(tier);
    return i >= 0 ? i + 1 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final asyncSegs = ref.watch(flowWeekSegmentsProvider);
    final asyncTarget = ref.watch(flowWeeklyTargetProvider);
    final progress = ref.watch(playerProgressProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        backgroundColor: AppChrome.topBarBackground,
        foregroundColor: AppChrome.topBarForeground,
        surfaceTintColor: Colors.transparent,
        title: const Text('플로우 트랙'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: () {
              ref.invalidate(flowWeekSegmentsProvider);
              ref.invalidate(flowWeeklyTargetProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  label: Text('트랙'),
                  icon: Icon(Icons.show_chart_rounded, size: 18),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Text('배지'),
                  icon: Icon(Icons.emoji_events_outlined, size: 18),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (next) {
                if (next.isEmpty) return;
                setState(() => _tab = next.first);
              },
            ),
          ),
          Expanded(
            child: _tab == 0
                ? _FlowTrackTab(
                    asyncSegs: asyncSegs,
                    asyncTarget: asyncTarget,
                    lineColor: _lineColor,
                    tierLevel: _tierLevel,
                  )
                : _FlowBadgesTab(progress: progress),
          ),
        ],
      ),
    );
  }
}

class _FlowTrackTab extends StatelessWidget {
  const _FlowTrackTab({
    required this.asyncSegs,
    required this.asyncTarget,
    required this.lineColor,
    required this.tierLevel,
  });

  final AsyncValue<List<FlowWeekSegment>> asyncSegs;
  final AsyncValue<int> asyncTarget;
  final Color lineColor;
  final int Function(String tier) tierLevel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        asyncSegs.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (segs) {
            if (segs.isEmpty) {
              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    '집중 기록이 쌓이면 현재 티어가 여기 표시돼요.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF5C6378)),
                  ),
                ),
              );
            }
            final last = segs.last;
            final tierKo = FlowTrackRepository.tierLabelKo(last.tier);
            final tierColor = FlowTrackTierStyle.accent(last.tier);
            final tierTint = FlowTrackTierStyle.cardTint(last.tier);
            return Card(
              elevation: 0,
              color: Color.alphaBlend(tierTint, Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: tierColor.withValues(alpha: 0.22)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.military_tech_rounded, color: tierColor, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '현재 티어',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: tierColor.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$tierKo · 연속 목표 달성 ${last.streakWeeks}주',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: tierColor,
                                  height: 1.25,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '레벨 ${tierLevel(last.tier)} · (${last.tier})',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: tierColor.withValues(alpha: 0.72),
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showFlowTrackAchievementsDialog(context),
            icon: const Icon(Icons.info_outline_rounded, size: 18),
            label: const Text('티어·주간 목표 안내'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: asyncTarget.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (t) => Text(
                '한 주는 월요일~일요일 기준이에요. 이번 주에 집중 완료를 $t회 이상 하면 파란 칩으로 표시돼요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF5C6378)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        asyncSegs.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 48),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(child: Text('$e')),
          data: (segs) {
            if (segs.isEmpty) {
              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    '아직 집중 기록이 없어요. 집중을 완료하면 트랙이 쌓여요.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
                  ),
                ),
              );
            }

            final view = segs.reversed.toList();
            return _FlowTimeline(
              segments: view,
              lineColor: lineColor,
              tierLevel: tierLevel,
            );
          },
        ),
      ],
    );
  }
}

String _badgeHint(String id) {
  for (final e in kBadgeCatalog) {
    if (e.id == id) return e.hint;
  }
  return '';
}

class _FlowBadgesTab extends StatelessWidget {
  const _FlowBadgesTab({required this.progress});

  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final earned = progress.badges.toSet();
    final locked = kBadgeCatalog.where((e) => !earned.contains(e.id)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text('받은 배지', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        if (earned.isEmpty)
          Text(
            '아직 받은 배지가 없어요.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF8E93A3)),
          )
        else
          ...[
            for (final id in progress.badges)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(Icons.emoji_events, color: Theme.of(context).colorScheme.primary),
                    title: Text(id, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _badgeHint(id),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
          ],
        const SizedBox(height: 24),
        Text('앞으로 받을 수 있어요', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        if (locked.isEmpty)
          Text(
            '카탈로그의 배지를 모두 받았어요!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF8E93A3)),
          )
        else
          for (final e in locked)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                elevation: 0,
                color: const Color(0xFFF0F1F6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(Icons.lock_outline_rounded, color: Colors.grey.shade500),
                  title: Text(e.id, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                  subtitle: Text(e.hint, style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            ),
      ],
    );
  }
}

class _FlowTimeline extends StatelessWidget {
  const _FlowTimeline({
    required this.segments,
    required this.lineColor,
    required this.tierLevel,
  });

  final List<FlowWeekSegment> segments;
  final Color lineColor;
  final int Function(String tier) tierLevel;

  static const _darkChip = Color(0xFF1A1C23);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          _TimelineEntry(
            segment: segments[i],
            isFirst: i == 0,
            isLast: i == segments.length - 1,
            lineColor: lineColor,
            tierLevel: tierLevel,
            darkChip: _darkChip,
          ),
          if (i < segments.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.segment,
    required this.isFirst,
    required this.isLast,
    required this.lineColor,
    required this.tierLevel,
    required this.darkChip,
  });

  final FlowWeekSegment segment;
  final bool isFirst;
  final bool isLast;
  final Color lineColor;
  final int Function(String tier) tierLevel;
  final Color darkChip;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final String title;
    late final String? subtitle;

    final weekSpan = _flowWeekRangeLabelKo(segment.weekStartDateKey);

    if (!segment.success) {
      bg = Colors.white;
      fg = const Color(0xFF6B7280);
      title = '$weekSpan · 집중 ${segment.completedCount}/${segment.weeklyTarget}회';
      subtitle = '아직 이번 주 목표(${segment.weeklyTarget}회)를 채우지 못했어요';
    } else if (segment.repairMark) {
      bg = darkChip;
      fg = Colors.white;
      title = '${segment.completedCount}/${segment.weeklyTarget}회 목표 달성!';
      subtitle = '$weekSpan · 한 주를 놓친 뒤 다시 이어졌어요 · 연속 ${segment.streakWeeks}주';
    } else {
      bg = FlowTrackTierStyle.accent(segment.tier);
      fg = FlowTrackTierStyle.onAccent(bg);
      final lv = tierLevel(segment.tier);
      title = '레벨 $lv 달성!!';
      subtitle = '$weekSpan · ${segment.tier} · 연속 ${segment.streakWeeks}주';
    }

    final iconBg = !segment.success ? const Color(0xFFE8EAEF) : bg;
    final iconFg = !segment.success ? const Color(0xFF7C8499) : fg;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isFirst)
                Center(
                  child: Container(
                    width: 2,
                    height: 18,
                    color: lineColor,
                  ),
                ),
              CircleAvatar(
                radius: 21,
                backgroundColor: iconBg,
                child: Icon(Icons.eco, color: iconFg, size: 22),
              ),
              if (!isLast)
                Center(
                  child: Container(
                    width: 2,
                    height: 18,
                    color: lineColor,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PillChip(
            backgroundColor: bg,
            foregroundColor: fg,
            subtitleColor: segment.success && !segment.repairMark
                ? FlowTrackTierStyle.subtitleOnAccent(bg)
                : null,
            title: title,
            subtitle: subtitle,
          ),
        ),
      ],
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.title,
    this.subtitle,
    this.subtitleColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: backgroundColor == Colors.white ? Border.all(color: const Color(0xFFE4E6ED)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.35,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: subtitleColor ?? foregroundColor.withValues(alpha: 0.88),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
