import '../domain/mcp_bridge.dart';

class NoopMcpBridge implements McpBridge {
  @override
  Future<List<String>> fetchExternalTasksPreview() async => const [];

  @override
  Future<void> openCrisisResourcesUri() async {}

  @override
  Future<void> rescheduleCalendar({required String rationale}) async {}
}
