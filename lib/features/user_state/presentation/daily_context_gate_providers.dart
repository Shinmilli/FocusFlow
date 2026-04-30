import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/user_local_data_scope.dart';
import '../data/daily_context_gate_prefs.dart';

final dailyContextGatePrefsProvider = Provider<DailyContextGatePrefs>((ref) {
  final scope = ref.watch(userLocalDataStorageSuffixProvider);
  return DailyContextGatePrefs(storageScope: scope);
});

final dailyContextDoneProvider = FutureProvider<bool>((ref) async {
  return ref.read(dailyContextGatePrefsProvider).isDoneForToday();
});

