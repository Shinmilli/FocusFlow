import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/api_config.dart';
import '../../user_state/domain/user_life_context.dart';
import '../domain/external_item.dart';
import '../domain/mcp_bridge.dart';
import 'device_calendar_service.dart';
import 'mcp_api_client.dart';

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
    try {
      return await _api!.fetchStatus();
    } catch (_) {
      return McpConnectionStatus.offline();
    }
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
    final results = <ExternalItem>[];

    if (_hasApi) {
      try {
        results.addAll(await _api!.fetchRemoteItems());
      } catch (_) {}
    }

    try {
      results.addAll(await _deviceCalendar.fetchUpcomingItems());
    } catch (_) {}

    return results;
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
      } catch (_) {}
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
  Future<void> rescheduleCalendar({required String rationale}) async {
    // 추후: 서버 MCP가 캘린더 일정 재배치 API 호출.
  }
}
