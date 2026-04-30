import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/user_local_data_scope.dart';
import '../data/coach_nudge_prefs.dart';

final coachNudgePrefsProvider = Provider<CoachNudgePrefs>((ref) {
  final scope = ref.watch(userLocalDataStorageSuffixProvider);
  return CoachNudgePrefs(storageScope: scope);
});

final coachNudgeIntensityProvider = FutureProvider<CoachNudgeIntensity>((ref) async {
  return ref.read(coachNudgePrefsProvider).intensity();
});

