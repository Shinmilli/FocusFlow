import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_providers.dart';

/// SharedPreferences 키 접미사.
///
/// - API 미설정: `'guest'` — 기존 단일 기기용(접미사 없는 레거시 키)과 동일 이름을 씁니다.
/// - API 설정 + 로그인: 사용자 id(정규화).
/// - API 설정 + 비로그인: `null` — 사용자 데이터는 디스크에 쓰지 않습니다.
final userLocalDataStorageSuffixProvider = Provider<String?>((ref) {
  final apiConfigured = ref.watch(
    authRepositoryProvider.select((r) => r.isApiConfigured),
  );
  if (!apiConfigured) return 'guest';

  final auth = ref.watch(authControllerProvider);
  if (auth.phase != AuthPhase.authenticated) return null;
  final id = auth.user?.id ?? '';
  if (id.isEmpty) return 'unknown';
  return id.replaceAll(RegExp(r'[^0-9a-zA-Z\-\_]'), '_');
});

/// [scope]가 `guest`이면 [legacyBaseKey] 그대로, 아니면 `legacyBaseKey.scope`.
/// [scope]가 null이면 호출부에서 디스크 접근을 하지 말아야 합니다.
String scopedPreferenceKey(String legacyBaseKey, String? scope) {
  if (scope == null) return legacyBaseKey;
  if (scope == 'guest') return legacyBaseKey;
  return '$legacyBaseKey.$scope';
}
