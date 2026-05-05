import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../../core/persistence/user_local_data_scope.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_providers.dart';

/// 로컬 변경 후 서버로 묶어 올리기 (디바운스).
class UserSyncScheduler {
  UserSyncScheduler(this._ref, this._pushFromLocal);

  final Ref _ref;
  final Future<void> Function() _pushFromLocal;
  Timer? _debounce;

  void dispose() {
    _debounce?.cancel();
  }

  void schedulePush() {
    if (!kApiBaseUrlConfigured) return;
    final auth = _ref.read(authControllerProvider);
    if (auth.phase != AuthPhase.authenticated) return;
    final scope = _ref.read(userLocalDataStorageSuffixProvider);
    if (scope == null || scope == 'guest') return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () async {
      try {
        await _pushFromLocal();
      } catch (_) {}
    });
  }
}
