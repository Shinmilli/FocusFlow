import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'ff_access_token';

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

  Future<void> writeToken(String token) async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      await p.setString(_tokenKey, token);
      return;
    }
    await _secure.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      await p.remove(_tokenKey);
      return;
    }
    await _secure.delete(key: _tokenKey);
  }
}
