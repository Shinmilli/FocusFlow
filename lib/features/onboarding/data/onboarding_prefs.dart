import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPrefs {
  OnboardingPrefs({SharedPreferences? prefs})
      : _prefsFuture = prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;

  static const _kDone = 'onboarding.done.v1';

  Future<bool> isDone() async {
    final p = await _prefsFuture;
    return p.getBool(_kDone) ?? false;
  }

  Future<void> setDone(bool done) async {
    final p = await _prefsFuture;
    await p.setBool(_kDone, done);
  }
}

