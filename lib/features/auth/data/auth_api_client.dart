import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../domain/auth_user.dart';

class AuthApiException implements Exception {
  AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthApiClient {
  AuthApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> _headers({bool jsonBody = false}) => {
        if (jsonBody) 'Content-Type': 'application/json',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  Future<(String token, AuthUser user)> register({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(apiUrl('/auth/register'));
    final res = await _client.post(
      uri,
      headers: _headers(jsonBody: true),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parseAuthResponse(res, successCodes: {201});
  }

  Future<(String token, AuthUser user)> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(apiUrl('/auth/login'));
    final res = await _client.post(
      uri,
      headers: _headers(jsonBody: true),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parseAuthResponse(res, successCodes: {200});
  }

  Future<AuthUser> me() async {
    final uri = Uri.parse(apiUrl('/auth/me'));
    final res = await _client.get(uri, headers: _headers());
    if (res.statusCode == 401) {
      throw AuthApiException('세션이 만료되었어요. 다시 로그인해 주세요.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthApiException('서버 오류 (${res.statusCode})');
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final userJson = map['user'] as Map<String, dynamic>;
    return AuthUser.fromJson(userJson);
  }

  Future<AuthUser> updateProfile({required String nickname}) async {
    final uri = Uri.parse(apiUrl('/user/profile'));
    final res = await _client.patch(
      uri,
      headers: _headers(jsonBody: true),
      body: jsonEncode({'nickname': nickname}),
    );
    if (res.statusCode == 401) {
      throw AuthApiException('세션이 만료되었어요. 다시 로그인해 주세요.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = '요청에 실패했어요';
      try {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        final err = map['error'];
        if (err is String && err.isNotEmpty) msg = err;
      } catch (_) {}
      throw AuthApiException(msg);
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final userJson = map['user'] as Map<String, dynamic>?;
    if (userJson == null) throw AuthApiException('서버 응답 형식이 올바르지 않아요');
    return AuthUser.fromJson(userJson);
  }

  (String, AuthUser) _parseAuthResponse(http.Response res, {required Set<int> successCodes}) {
    if (!successCodes.contains(res.statusCode)) {
      String msg = '요청에 실패했어요';
      try {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        final err = map['error'];
        if (err is String && err.isNotEmpty) msg = err;
      } catch (_) {}
      throw AuthApiException(msg);
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final token = map['accessToken'] as String?;
    final userJson = map['user'] as Map<String, dynamic>?;
    if (token == null || token.isEmpty || userJson == null) {
      throw AuthApiException('서버 응답 형식이 올바르지 않아요');
    }
    return (token, AuthUser.fromJson(userJson));
  }
}
