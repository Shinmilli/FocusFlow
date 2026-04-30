import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/persistence/user_local_data_scope.dart';

class OnboardingPrefs {
  OnboardingPrefs({
    required this.storageScope,
    SharedPreferences? prefs,
  }) : _prefsFuture = prefs != null ? Future.value(prefs) : SharedPreferences.getInstance();

  final String? storageScope;

  final Future<SharedPreferences> _prefsFuture;

  static const _kDoneBase = 'onboarding.done.v1';

  String? get _kDone => storageScope == null ? null : scopedPreferenceKey(_kDoneBase, storageScope);

  Future<bool> isDone() async {
    final key = _kDone;
    if (key == null) return false;
    final p = await _prefsFuture;
    return p.getBool(key) ?? false;
  }

  Future<void> setDone(bool done) async {
    final key = _kDone;
    if (key == null) return;
    final p = await _prefsFuture;
    await p.setBool(key, done);
  }
}

