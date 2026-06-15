import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/api_config.dart';
import '../../user_state/domain/user_life_context.dart';
import '../domain/external_item.dart';
import '../domain/mcp_bridge.dart';
import 'device_calendar_service.dart';
import 'mcp_api_client.dart';

class McpFetchBundle {
  const McpFetchBundle({
    required this.items,
    this.warnings = const [],
  });

  final List<ExternalItem> items;
  final List<String> warnings;
}

/// 서버 MCP + 기기 캘린더를 합친 실제 브리지.
class FocusFlowMcpBridge implements McpBridge {
  FocusFlowMcpBridge({
    required McpApiClient? api,
    DeviceCalendarService? deviceCalendar,
  })  : _api = api,
        _deviceCalendar = deviceCalendar ?? DeviceCalendarService();

  final McpApiClient? _api;
  final DeviceCalendarService _deviceCalendar;

  bool get _hasApi => _api != null && kApiBaseUrlConfigured;

  @override
  Future<McpConnectionStatus> fetchConnectionStatus() async {
    if (!_hasApi) return McpConnectionStatus.offline();
    return _api!.fetchStatus();
  }

  @override
  Future<String?> startOAuth(McpOAuthProvider provider) async {
    if (!_hasApi) return null;
    return _api!.fetchOAuthUrl(provider);
  }

  @override
  Future<void> disconnect(McpOAuthProvider provider) async {
    if (!_hasApi) return;
    await _api!.disconnect(provider);
  }

  @override
  Future<List<ExternalItem>> fetchExternalItems() async {
    final bundle = await fetchExternalItemsDetailed();
    return bundle.items;
  }

  Future<McpFetchBundle> fetchExternalItemsDetailed() async {
    final results = <ExternalItem>[];
    final warnings = <String>[];

    if (_hasApi) {
      try {
        final remote = await _api!.fetchRemoteItems();
        results.addAll(remote.items);
        warnings.addAll(remote.warnings);
      } on McpApiException catch (e) {
        warnings.add(e.message);
      }
    } else {
      warnings.add('API 서버에 연결되지 않았어요.');
    }

    try {
      final local = await _deviceCalendar.fetchUpcomingItems();
      results.addAll(local);
      if (local.isEmpty && _deviceCalendar.isSupported) {
        warnings.add('기기 캘린더 권한이 없거나 오늘·내일 일정이 없어요.');
      }
    } catch (e) {
      warnings.add('기기 캘린더: $e');
    }

    return McpFetchBundle(items: results, warnings: warnings);
  }

  @override
  Future<McpOrganizeProposal> organizeWithAi({
    required List<ExternalItem> items,
    required UserLifeContext lifeContext,
    required List<String> existingTitles,
  }) async {
    if (_hasApi) {
      try {
        final proposal = await _api!.organize(
          items: items,
          lifeContext: lifeContext,
          existingTitles: existingTitles,
        );
        if (proposal.blocks.isNotEmpty) return proposal;
      } on McpApiException {
        // Gemini 실패 시 로컬 휴리스틱으로 폴백.
      }
    }
    return fallbackOrganizeProposal(items: items, lifeContext: lifeContext);
  }

  @override
  Future<List<String>> fetchExternalTasksPreview() => defaultExternalTasksPreview(this);

  @override
  Future<void> openCrisisResourcesUri() async {
    final uri = Uri.parse('https://www.mohw.go.kr/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Future<void> rescheduleCalendar({required String rationale}) async {}
}
