import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notifications/data/daily_reminder_prefs.dart';
import '../../../notifications/presentation/notification_providers.dart';

class DailyReminderCard extends ConsumerWidget {
  const DailyReminderCard({super.key});

  String _fmt(int h, int m) {
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dailyReminderStateProvider);

    return async.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('리마인더 설정을 불러오지 못했어요: $e'),
        ),
      ),
      data: (s) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('매일 리마인더', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  '같은 시각에 “오늘 1단계” 알림을 보내요. (재부팅 후엔 앱을 한 번 열면 다시 잡혀요)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.enabled ? '켜짐 · ${_fmt(s.hour, s.minute)}' : '꺼짐'),
                  value: s.enabled,
                  onChanged: (v) async {
                    await applyDailyReminder(
                      ref,
                      DailyReminderState(enabled: v, hour: s.hour, minute: s.minute),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: s.hour, minute: s.minute),
                      );
                      if (picked == null) return;
                      await applyDailyReminder(
                        ref,
                        DailyReminderState(
                          enabled: true,
                          hour: picked.hour,
                          minute: picked.minute,
                        ),
                      );
                    },
                    icon: const Icon(Icons.schedule),
                    label: const Text('시간 선택'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
