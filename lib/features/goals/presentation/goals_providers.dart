import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/user_local_data_scope.dart';
import '../data/goals_prefs.dart';

final goalsPrefsProvider = Provider<GoalsPrefs>((ref) {
  final scope = ref.watch(userLocalDataStorageSuffixProvider);
  return GoalsPrefs(storageScope: scope);
});

final goalsProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(goalsPrefsProvider).load();
});

