import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/data/auth_api_client.dart';

class UserSyncApiException implements Exception {
  UserSyncApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// GET /sync/state · PUT /sync/state
class UserSyncApiClient {
  UserSyncApiClient({
    required AuthApiClient auth,
    http.Client? client,
  })  : _auth = auth,
        _client = client ?? http.Client();

  final AuthApiClient _auth;
  final http.Client _client;

  Future<Map<String, dynamic>> fetchPayload() async {
    final uri = Uri.parse(apiUrl('/sync/state'));
    final res = await _client.get(uri, headers: _auth.authorizedHeaders());
    if (res.statusCode == 401) {
      throw UserSyncApiException('동기화 인증이 만료되었어요.', statusCode: 401);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw UserSyncApiException('동기화를 불러오지 못했어요 (${res.statusCode})', statusCode: res.statusCode);
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final payload = map['payload'];
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return payload.cast<String, dynamic>();
    return {};
  }

  Future<void> putPayload(Map<String, dynamic> payload) async {
    final uri = Uri.parse(apiUrl('/sync/state'));
    final res = await _client.put(
      uri,
      headers: _auth.authorizedHeaders(jsonBody: true),
      body: jsonEncode({'payload': payload}),
    );
    if (res.statusCode == 401) {
      throw UserSyncApiException('동기화 인증이 만료되었어요.', statusCode: 401);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw UserSyncApiException('동기화 저장에 실패했어요 (${res.statusCode})', statusCode: res.statusCode);
    }
  }
}
