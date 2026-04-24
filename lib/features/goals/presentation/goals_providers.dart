import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/goals_prefs.dart';

final goalsPrefsProvider = Provider<GoalsPrefs>((ref) => GoalsPrefs());

final goalsProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(goalsPrefsProvider).load();
});

