import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/onboarding_prefs.dart';

final onboardingPrefsProvider = Provider<OnboardingPrefs>((ref) => OnboardingPrefs());

final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  return ref.read(onboardingPrefsProvider).isDone();
});

