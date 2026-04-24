import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/daily_context_gate_prefs.dart';

final dailyContextGatePrefsProvider =
    Provider<DailyContextGatePrefs>((ref) => DailyContextGatePrefs());

final dailyContextDoneProvider = FutureProvider<bool>((ref) async {
  return ref.read(dailyContextGatePrefsProvider).isDoneForToday();
});

