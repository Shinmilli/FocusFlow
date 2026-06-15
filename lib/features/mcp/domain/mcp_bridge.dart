import '../../user_state/domain/user_life_context.dart';
import 'external_item.dart';

/// Model Context Protocol: 외부 도구(캘린더, 노션…)를 AI가 호출할 때의 경계.
abstract class McpBridge {
  Future<McpConnectionStatus> fetchConnectionStatus();

  Future<String?> startOAuth(McpOAuthProvider provider);

  Future<void> disconnect(McpOAuthProvider provider);

  /// 구글·노션(서버) + 삼성/기기 캘린더(로컬) 항목을 모읍니다.
  Future<List<ExternalItem>> fetchExternalItems();

  /// AI가 외부 항목을 오늘 집중 블록으로 정리합니다.
  Future<McpOrganizeProposal> organizeWithAi({
    required List<ExternalItem> items,
    required UserLifeContext lifeContext,
    required List<String> existingTitles,
  });

  Future<void> rescheduleCalendar({required String rationale});

  Future<void> openCrisisResourcesUri();

  Future<List<String>> fetchExternalTasksPreview();
}

Future<List<String>> defaultExternalTasksPreview(McpBridge bridge) async {
  final items = await bridge.fetchExternalItems();
  if (items.isEmpty) {
    return const [
      '연결된 외부 항목이 없어요. MCP 연결 화면에서 계정을 연결하거나 기기 캘린더 권한을 허용해 주세요.',
    ];
  }
  return items.map((i) => '${i.sourceLabel} — ${i.title}').toList();
}

/// 서버 Gemini 없을 때 로컬 휴리스틱 정리.
McpOrganizeProposal fallbackOrganizeProposal({
  required List<ExternalItem> items,
  required UserLifeContext lifeContext,
}) {
  final soft = lifeContext.planIntensityMultiplier < 0.85;
  final picked = items.take(3).toList();
  final blocks = picked
      .map(
        (item) => McpOrganizedBlock(
          title: item.title,
          units: soft
              ? ['준비 2분', '핵심만 10분', '마무리 3분']
              : ['시작 3분', '핵심 15분', '정리 5분'],
          sourceRefs: [item.refKey],
        ),
      )
      .toList();

  return McpOrganizeProposal(
    messageForUser: soft
        ? '외부에서 받은 일을 작게 쪼갰어요. 가장 가벼운 블록 하나만 골라 5분부터 시작해 봐요.'
        : '외부 일정·할 일을 오늘 집중 블록으로 정리했어요. 하나 골라 바로 시작해요.',
    blocks: blocks,
  );
}
