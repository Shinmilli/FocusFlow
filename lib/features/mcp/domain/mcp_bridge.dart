/// Model Context Protocol: 외부 도구(캘린더, 노션, LMS…)를 AI가 호출할 때의 경계.
///
/// Flutter 앱에서는 보통 (1) 백엔드 MCP 호스트 또는 (2) 사용자 기기의
/// 허용된 OAuth 스코프만 노출하는 게 안전합니다. 여기서는 인터페이스만 둡니다.
abstract class McpBridge {
  Future<void> rescheduleCalendar({required String rationale});
  Future<List<String>> fetchExternalTasksPreview();
  Future<void> openCrisisResourcesUri();
}
