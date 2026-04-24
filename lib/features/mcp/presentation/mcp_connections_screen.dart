import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mcp_providers.dart';

class McpConnectionsScreen extends ConsumerWidget {
  const McpConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bridge = ref.watch(mcpBridgeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('외부 도구 (MCP 데모)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '실제 연동은 OAuth·백엔드 MCP가 필요해요. 여기서는 앱 안에서 “연결되면 이렇게 동작한다”를 보여줘요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.calendar_month_outlined),
              title: Text('Google Calendar'),
              subtitle: Text('일정 재배치 · 마감 반영 (연동 예정)'),
              trailing: Text('데모'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.note_alt_outlined),
              title: Text('Notion'),
              subtitle: Text('할 일 가져오기 · 블록 분해 (연동 예정)'),
              trailing: Text('데모'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.school_outlined),
              title: Text('학교 LMS'),
              subtitle: Text('과제·마감 요약 (연동 예정)'),
              trailing: Text('데모'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final items = await bridge.fetchExternalTasksPreview();
              if (!context.mounted) return;
              showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('외부 작업 미리보기'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [for (final t in items) Text('• $t')],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('닫기')),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.preview_outlined),
            label: const Text('미리보기 작업 불러오기'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => bridge.openCrisisResourcesUri(),
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('정신건강 정보(브라우저)'),
          ),
        ],
      ),
    );
  }
}
