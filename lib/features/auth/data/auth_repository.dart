import '../../../core/config/api_config.dart';
import '../domain/auth_user.dart';
import 'auth_api_client.dart';
import 'token_storage.dart';

class AuthRepository {
  AuthRepository({
    required AuthApiClient api,
    required TokenStorage storage,
  })  : _api = api,
        _storage = storage;

  final AuthApiClient _api;
  final TokenStorage _storage;

  bool get isApiConfigured => kApiBaseUrlConfigured;

  Future<AuthUser?> tryRestoreSession() async {
    if (!isApiConfigured) return null;
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) return null;
    _api.setToken(token);
    try {
      return await _api.me();
    } on AuthApiException {
      await _storage.clearToken();
      _api.setToken(null);
      return null;
    }
  }

  Future<AuthUser> login(String email, String password) async {
    final (token, user) = await _api.login(email: email, password: password);
    await _storage.writeToken(token);
    _api.setToken(token);
    return user;
  }

  Future<AuthUser> register(String email, String password) async {
    final (token, user) = await _api.register(email: email, password: password);
    await _storage.writeToken(token);
    _api.setToken(token);
    return user;
  }

  Future<void> logout() async {
    await _storage.clearToken();
    _api.setToken(null);
  }

  Future<AuthUser> updateNickname(String nickname) async {
    final user = await _api.updateProfile(nickname: nickname);
    return user;
  }
}
