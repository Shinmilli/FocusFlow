import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/data/auth_api_client.dart';
import '../../user_state/domain/user_life_context.dart';
import '../domain/external_item.dart';

class McpApiException implements Exception {
  McpApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class McpFetchResult {
  const McpFetchResult({
    required this.items,
    this.warnings = const [],
  });

  final List<ExternalItem> items;
  final List<String> warnings;
}

class McpApiClient {
  McpApiClient({
    required AuthApiClient auth,
    http.Client? client,
  })  : _auth = auth,
        _client = client ?? http.Client();

  final AuthApiClient _auth;
  final http.Client _client;

  Future<McpConnectionStatus> fetchStatus() async {
    final uri = Uri.parse(apiUrl('/mcp/status'));
    final res = await _client.get(uri, headers: _auth.authorizedHeaders());
    _throwIfBad(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return McpConnectionStatus.fromJson(map);
  }

  /// 로그인 없이 서버 OAuth 설정 여부만 확인 (Render env 누락 진단용).
  Future<McpConnectionStatus> fetchPublicConfig() async {
    final uri = Uri.parse(apiUrl('/mcp/config'));
    final res = await _client.get(uri);
    if (res.statusCode == 404) {
      throw McpApiException(
        '서버에 MCP API가 없어요. 최신 코드를 Render에 배포해 주세요.',
        statusCode: 404,
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw McpApiException('서버 설정 확인 실패 (${res.statusCode})', statusCode: res.statusCode);
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final google = map['google'] as Map<String, dynamic>? ?? {};
    final notion = map['notion'] as Map<String, dynamic>? ?? {};
    final googleMissing = (google['missing'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    return McpConnectionStatus(
      google: McpProviderStatus(
        configured: google['configured'] == true,
        connected: false,
        note: googleMissing.isEmpty ? null : 'Render에 추가: ${googleMissing.join(", ")}',
      ),
      notion: McpProviderStatus(
        configured: notion['configured'] == true,
        connected: false,
      ),
      samsungCalendar: const McpProviderStatus(
        configured: true,
        connected: false,
        note: '기기에서 직접 읽어요',
      ),
    );
  }

  Future<String> fetchOAuthUrl(McpOAuthProvider provider) async {
    final path = provider == McpOAuthProvider.google
        ? '/mcp/google/auth-url'
        : '/mcp/notion/auth-url';
    final uri = Uri.parse(apiUrl(path));
    final res = await _client.get(uri, headers: _auth.authorizedHeaders());
    _throwIfBad(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final url = map['url'] as String?;
    if (url == null || url.isEmpty) {
      throw McpApiException('OAuth URL을 받지 못했어요');
    }
    return url;
  }

  Future<void> disconnect(McpOAuthProvider provider) async {
    final uri = Uri.parse(apiUrl('/mcp/disconnect'));
    final res = await _client.post(
      uri,
      headers: _auth.authorizedHeaders(jsonBody: true),
      body: jsonEncode({
        'provider': provider == McpOAuthProvider.google ? 'google' : 'notion',
      }),
    );
    _throwIfBad(res);
  }

  Future<McpFetchResult> fetchRemoteItems() async {
    final uri = Uri.parse(apiUrl('/mcp/fetch'));
    final res = await _client.post(
      uri,
      headers: _auth.authorizedHeaders(jsonBody: true),
      body: jsonEncode({}),
    );
    _throwIfBad(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final items = map['items'] as List<dynamic>? ?? [];
    final warningsRaw = map['warnings'] as List<dynamic>? ?? [];
    final warnings = warningsRaw
        .whereType<Map<String, dynamic>>()
        .map((w) => (w['message'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();

    return McpFetchResult(
      items: items
          .whereType<Map<String, dynamic>>()
          .map(ExternalItem.fromJson)
          .where((i) => i.title.isNotEmpty)
          .toList(),
      warnings: warnings,
    );
  }

  Future<McpOrganizeProposal> organize({
    required List<ExternalItem> items,
    required UserLifeContext lifeContext,
    required List<String> existingTitles,
  }) async {
    final uri = Uri.parse(apiUrl('/mcp/organize'));
    final res = await _client.post(
      uri,
      headers: _auth.authorizedHeaders(jsonBody: true),
      body: jsonEncode({
        'items': items.map((i) => i.toJson()).toList(),
        'lifeContext': {
          'sleepHours': lifeContext.sleepHours,
          'stressLevel': lifeContext.stressLevel,
          'phoneHeavyUse': lifeContext.phoneHeavyUse,
          'examPeriod': lifeContext.examPeriod,
          'burnoutRisk': lifeContext.burnoutRisk,
          'planIntensityMultiplier': lifeContext.planIntensityMultiplier,
        },
        'existingTitles': existingTitles,
      }),
    );
    _throwIfBad(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return McpOrganizeProposal.fromJson(map);
  }

  void _throwIfBad(http.Response res) {
    if (res.statusCode == 401) {
      throw McpApiException('인증이 만료되었어요. 다시 로그인해 주세요.', statusCode: 401);
    }
    if (res.statusCode == 404) {
      throw McpApiException(
        '서버에 MCP API가 없어요. Render에 최신 코드를 배포했는지 확인해 주세요.',
        statusCode: 404,
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = '요청에 실패했어요 (${res.statusCode})';
      try {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        final err = map['error'];
        if (err is String && err.isNotEmpty) msg = err;
      } catch (_) {}
      throw McpApiException(msg, statusCode: res.statusCode);
    }
  }
}
