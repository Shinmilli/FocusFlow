import 'package:url_launcher/url_launcher.dart';

import '../domain/mcp_bridge.dart';

/// 서버/MCP 호스트 없이 UX·포지셔닝용 데모. 실제 OAuth·API는 추후 백엔드와 연결.
class DemoMcpBridge implements McpBridge {
  @override
  Future<List<String>> fetchExternalTasksPreview() async {
    return const [
      '(데모) Google Calendar — 오늘 일정 미리보기',
      '(데모) Notion — 할 일 블록 불러오기',
      '(데모) 학교 LMS — 마감 과제 요약',
    ];
  }

  @override
  Future<void> openCrisisResourcesUri() async {
    final uri = Uri.parse('https://www.mohw.go.kr/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Future<void> rescheduleCalendar({required String rationale}) async {
    // 실제 연동 시: 백엔드 MCP가 캘린더 API 호출.
  }
}
