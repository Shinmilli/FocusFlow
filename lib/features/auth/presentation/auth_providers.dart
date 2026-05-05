import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/router_refresh.dart';
import '../data/auth_api_client.dart';
import '../data/auth_repository.dart';
import '../data/token_storage.dart';
import '../domain/auth_state.dart';
import '../domain/auth_user.dart';

final routerRefreshListenableProvider = Provider<GoRouterRefreshNotifier>((ref) {
  final n = GoRouterRefreshNotifier();
  ref.onDispose(n.dispose);
  return n;
});

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final authApiClientProvider = Provider<AuthApiClient>((ref) => AuthApiClient());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(authApiClientProvider),
    storage: ref.watch(tokenStorageProvider),
  );
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  /// 로그인·가입 직후 홈(오늘의 프로젝트)에서 AI 오늘 계획을 한 번 띄울 때 사용.
  bool _pendingAiTodayPlanOnHome = false;

  @override
  AuthState build() {
    if (!_repo.isApiConfigured) {
      return const AuthState.unauthenticated();
    }
    Future.microtask(_bootstrap);
    return const AuthState.bootstrapping();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  void _notifyRouter() => ref.read(routerRefreshListenableProvider).notify();

  Future<void> _bootstrap() async {
    try {
      final user = await _repo.tryRestoreSession();
      state = user != null ? AuthState.authenticated(user) : const AuthState.unauthenticated();
    } catch (_) {
      state = const AuthState.unauthenticated();
    }
    _notifyRouter();
  }

  Future<AuthUser> login(String email, String password) async {
    final user = await _repo.login(email, password);
    state = AuthState.authenticated(user);
    _pendingAiTodayPlanOnHome = true;
    _notifyRouter();
    return user;
  }

  Future<AuthUser> register(String email, String password) async {
    final user = await _repo.register(email, password);
    state = AuthState.authenticated(user);
    _pendingAiTodayPlanOnHome = true;
    _notifyRouter();
    return user;
  }

  /// 홈에서 소비하면 false로 돌아감. 한 번만 true.
  bool consumePendingAiTodayPlanOnHome() {
    if (!_pendingAiTodayPlanOnHome) return false;
    _pendingAiTodayPlanOnHome = false;
    return true;
  }

  Future<void> logout() async {
    await _repo.logout();
    _pendingAiTodayPlanOnHome = false;
    state = const AuthState.unauthenticated();
    _notifyRouter();
  }

  Future<AuthUser> updateNickname(String nickname) async {
    final user = await _repo.updateNickname(nickname);
    state = AuthState.authenticated(user);
    _notifyRouter();
    return user;
  }
}
