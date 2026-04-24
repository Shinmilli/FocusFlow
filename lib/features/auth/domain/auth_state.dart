import 'auth_user.dart';

enum AuthPhase {
  bootstrapping,
  unauthenticated,
  authenticated,
}

class AuthState {
  const AuthState._(this.phase, this.user);

  const AuthState.bootstrapping() : this._(AuthPhase.bootstrapping, null);

  const AuthState.unauthenticated() : this._(AuthPhase.unauthenticated, null);

  const AuthState.authenticated(AuthUser user) : this._(AuthPhase.authenticated, user);

  final AuthPhase phase;
  final AuthUser? user;
}
