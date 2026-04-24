import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/coach_nudge_prefs.dart';

final coachNudgePrefsProvider = Provider<CoachNudgePrefs>((ref) => CoachNudgePrefs());

final coachNudgeIntensityProvider = FutureProvider<CoachNudgeIntensity>((ref) async {
  return ref.read(coachNudgePrefsProvider).intensity();
});

