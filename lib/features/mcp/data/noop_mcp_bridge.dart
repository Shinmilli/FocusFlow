import '../../user_state/domain/user_life_context.dart';
import '../domain/external_item.dart';
import '../domain/mcp_bridge.dart';

class NoopMcpBridge implements McpBridge {
  @override
  Future<McpConnectionStatus> fetchConnectionStatus() async {
    return McpConnectionStatus.offline();
  }

  @override
  Future<String?> startOAuth(McpOAuthProvider provider) async => null;

  @override
  Future<void> disconnect(McpOAuthProvider provider) async {}

  @override
  Future<List<ExternalItem>> fetchExternalItems() async => const [];

  @override
  Future<McpOrganizeProposal> organizeWithAi({
    required List<ExternalItem> items,
    required UserLifeContext lifeContext,
    required List<String> existingTitles,
  }) async {
    return const McpOrganizeProposal(messageForUser: '', blocks: []);
  }

  @override
  Future<List<String>> fetchExternalTasksPreview() async => const [];

  @override
  Future<void> openCrisisResourcesUri() async {}

  @override
  Future<void> rescheduleCalendar({required String rationale}) async {}
}
