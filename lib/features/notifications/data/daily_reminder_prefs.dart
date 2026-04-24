import 'package:shared_preferences/shared_preferences.dart';

class DailyReminderPrefs {
  DailyReminderPrefs._();

  static const _kEnabled = 'dailyReminder.enabled.v1';
  static const _kHour = 'dailyReminder.hour.v1';
  static const _kMinute = 'dailyReminder.minute.v1';

  static Future<DailyReminderState> load() async {
    final p = await SharedPreferences.getInstance();
    return DailyReminderState(
      enabled: p.getBool(_kEnabled) ?? false,
      hour: p.getInt(_kHour) ?? 21,
      minute: p.getInt(_kMinute) ?? 0,
    );
  }

  static Future<void> save(DailyReminderState s) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, s.enabled);
    await p.setInt(_kHour, s.hour);
    await p.setInt(_kMinute, s.minute);
  }
}

class DailyReminderState {
  const DailyReminderState({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;
}
