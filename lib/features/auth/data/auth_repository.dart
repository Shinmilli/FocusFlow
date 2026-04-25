import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../domain/auth_user.dart';
import 'auth_api_client.dart';
import 'token_storage.dart';

bool _transientHttpStatus(int? code) =>
    code == 502 || code == 503 || code == 504 || code == 408;

/// Render cold start / edge 502 often has no CORS headers; the browser reports a failed fetch.
Future<T> _withColdStartRetry<T>(AuthApiClient api, Future<T> Function() run) async {
  const maxAttempts = 12;
  const pause = Duration(seconds: 2);

  for (var i = 0; i < maxAttempts; i++) {
    try {
      return await run();
    } on AuthApiException catch (e) {
      if (e.statusCode == 401) rethrow;
      if (!_transientHttpStatus(e.statusCode)) rethrow;
      if (i >= maxAttempts - 1) {
        throw AuthApiException(
          '서버가 깨어나는 중이에요. 잠시 후 다시 시도해 주세요.',
          statusCode: e.statusCode,
        );
      }
    } on http.ClientException catch (_) {
      if (i >= maxAttempts - 1) {
        throw AuthApiException('네트워크 또는 서버 시작을 기다리는 중이에요. 잠시 후 다시 시도해 주세요.');
      }
    }
    try {
      await api.pingHealth();
    } catch (_) {}
    await Future<void>.delayed(pause);
  }
  throw AuthApiException('연결에 실패했어요. 잠시 후 다시 시도해 주세요.');
}

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

    AuthUser? cachedUser;
    final cachedJson = await _storage.readCachedUserJson();
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        cachedUser = AuthUser.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
      } catch (_) {}
    }

    _api.setToken(token);
    try {
      final user = await _withColdStartRetry(_api, () => _api.me());
      await _storage.writeCachedUserJson(jsonEncode(user.toJson()));
      return user;
    } on AuthApiException catch (e) {
      if (e.statusCode == 401) {
        await _storage.clearToken();
        _api.setToken(null);
        return null;
      }
      if (cachedUser != null) {
        return cachedUser;
      }
      return null;
    }
  }

  Future<AuthUser> login(String email, String password) async {
    final (token, user) = await _withColdStartRetry(
      _api,
      () => _api.login(email: email, password: password),
    );
    await _storage.writeToken(token);
    await _storage.writeCachedUserJson(jsonEncode(user.toJson()));
    _api.setToken(token);
    return user;
  }

  Future<AuthUser> register(String email, String password) async {
    final (token, user) = await _withColdStartRetry(
      _api,
      () => _api.register(email: email, password: password),
    );
    await _storage.writeToken(token);
    await _storage.writeCachedUserJson(jsonEncode(user.toJson()));
    _api.setToken(token);
    return user;
  }

  Future<void> logout() async {
    await _storage.clearToken();
    _api.setToken(null);
  }

  Future<AuthUser> updateNickname(String nickname) async {
    final user = await _api.updateProfile(nickname: nickname);
    await _storage.writeCachedUserJson(jsonEncode(user.toJson()));
    return user;
  }
}
