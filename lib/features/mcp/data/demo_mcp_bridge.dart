import 'package:url_launcher/url_launcher.dart';

import '../../user_state/domain/user_life_context.dart';
import '../domain/external_item.dart';
import '../domain/mcp_bridge.dart';

/// API 없이 UX 확인용 데모. 기기 캘린더는 FocusFlowMcpBridge에서 처리.
class DemoMcpBridge implements McpBridge {
  @override
  Future<McpConnectionStatus> fetchConnectionStatus() async {
    return McpConnectionStatus.offline();
  }

  @override
  Future<String?> startOAuth(McpOAuthProvider provider) async => null;

  @override
  Future<void> disconnect(McpOAuthProvider provider) async {}

  @override
  Future<List<ExternalItem>> fetchExternalItems() async {
    return const [
      ExternalItem(
        source: 'google_calendar',
        title: '(데모) 팀 미팅 14:00',
        kind: 'event',
      ),
      ExternalItem(
        source: 'notion',
        title: '(데모) 레포트 초안 작성',
        kind: 'task',
      ),
      ExternalItem(
        source: 'device_calendar',
        title: '(데모) 삼성 캘린더 — 병원 예약',
        kind: 'event',
      ),
    ];
  }

  @override
  Future<McpOrganizeProposal> organizeWithAi({
    required List<ExternalItem> items,
    required UserLifeContext lifeContext,
    required List<String> existingTitles,
  }) async {
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
