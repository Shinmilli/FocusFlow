import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'ff_access_token';
const _userJsonKey = 'ff_auth_user_json';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  Future<String?> readToken() async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      return p.getString(_tokenKey);
    }
    return _secure.read(key: _tokenKey);
  }

  /// Last known profile from login/me; used to stay signed in when the API is briefly unreachable.
  Future<String?> readCachedUserJson() async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      return p.getString(_userJsonKey);
    }
    return _secure.read(key: _userJsonKey);
  }

  Future<void> writeToken(String token) async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      await p.setString(_tokenKey, token);
      return;
    }
    await _secure.write(key: _tokenKey, value: token);
  }

  Future<void> writeCachedUserJson(String json) async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      await p.setString(_userJsonKey, json);
      return;
    }
    await _secure.write(key: _userJsonKey, value: json);
  }

  Future<void> clearToken() async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      await p.remove(_tokenKey);
      await p.remove(_userJsonKey);
      return;
    }
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _userJsonKey);
  }
}
