import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/user_local_data_scope.dart';
import '../data/onboarding_prefs.dart';

final onboardingPrefsProvider = Provider<OnboardingPrefs>((ref) {
  final scope = ref.watch(userLocalDataStorageSuffixProvider);
  return OnboardingPrefs(storageScope: scope);
});

final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  return ref.read(onboardingPrefsProvider).isDone();
});

