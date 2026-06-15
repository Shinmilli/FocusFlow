import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/layout/embedded_screen_shell.dart';
import '../../../app/theme/app_chrome.dart';
import '../../../core/config/api_config.dart';
import '../domain/external_item.dart';
import 'mcp_organize_flow.dart';
import 'mcp_providers.dart';

class McpConnectionsScreen extends ConsumerStatefulWidget {
  const McpConnectionsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<McpConnectionsScreen> createState() => _McpConnectionsScreenState();
}

class _McpConnectionsScreenState extends ConsumerState<McpConnectionsScreen> {
  bool _refreshing = false;

  Future<void> _refreshStatus() async {
    setState(() => _refreshing = true);
    ref.invalidate(mcpConnectionStatusProvider);
    await ref.read(mcpConnectionStatusProvider.future);
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _connect(McpOAuthProvider provider) async {
    try {
      final bridge = ref.read(mcpBridgeProvider);
      final url = await bridge.startOAuth(provider);
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('서버 OAuth 설정이 필요해요. Render에 GOOGLE_CLIENT_ID 등을 넣었는지 확인해 주세요.'),
          ),
        );
        return;
      }
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('브라우저에서 연결 중… 잠시 후 자동으로 상태를 확인해요.')),
        );
        _pollConnectionAfterOAuth(provider);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _pollConnectionAfterOAuth(McpOAuthProvider provider) async {
    for (var i = 0; i < 15; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      ref.invalidate(mcpConnectionStatusProvider);
      final status = await ref.read(mcpConnectionStatusProvider.future);
      final connected = provider == McpOAuthProvider.google
          ? status.google.connected
          : status.notion.connected;
      if (connected) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('연결됐어요!')),
        );
        return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('아직 연결 확인이 안 돼요. 새로고침을 눌러 보세요.')),
    );
  }

  Future<void> _disconnect(McpOAuthProvider provider) async {
    final bridge = ref.read(mcpBridgeProvider);
    await bridge.disconnect(provider);
    ref.invalidate(mcpConnectionStatusProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('연결을 해제했어요')));
  }

  @override
  Widget build(BuildContext context) {
    final bridge = ref.watch(mcpBridgeProvider);
    final statusAsync = ref.watch(mcpConnectionStatusProvider);

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
            'Notion · Google Calendar · 삼성(기기) 캘린더에서 받은 일을 AI가 정리하고, 바로 집중 모드로 이어져요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (!kApiBaseUrlConfigured) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
              child: const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('로컬 모드'),
                subtitle: Text('API_BASE_URL이 없으면 Google·Notion OAuth는 비활성이에요. 기기 캘린더만 사용할 수 있어요.'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          statusAsync.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => Text('$e'),
            data: (status) => Column(
              children: [
                _ProviderCard(
                  icon: Icons.calendar_month_outlined,
                  title: 'Google Calendar',
                  subtitle: '오늘·내일 일정 가져오기',
                  configured: status.google.configured,
                  connected: status.google.connected,
                  onConnect: () => _connect(McpOAuthProvider.google),
                  onDisconnect: () => _disconnect(McpOAuthProvider.google),
                ),
                _ProviderCard(
                  icon: Icons.note_alt_outlined,
                  title: 'Notion',
                  subtitle: '할 일 페이지 가져오기',
                  configured: status.notion.configured,
                  connected: status.notion.connected,
                  onConnect: () => _connect(McpOAuthProvider.notion),
                  onDisconnect: () => _disconnect(McpOAuthProvider.notion),
                ),
                _ProviderCard(
                  icon: Icons.phone_android_outlined,
                  title: '삼성 / 기기 캘린더',
                  subtitle: status.samsungCalendar.note ?? '앱에서 캘린더 권한 허용 시 자동 연동',
                  configured: true,
                  connected: true,
                  onConnect: null,
                  onDisconnect: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => openMcpOrganizeFlow(context, ref),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('외부 일정 · 할 일 AI 정리하기'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final items = await bridge.fetchExternalTasksPreview();
              if (!context.mounted) return;
              showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('외부 항목 미리보기'),
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
            label: const Text('미리보기만 보기'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => bridge.openCrisisResourcesUri(),
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('정신건강 정보(브라우저)'),
          ),
        ],
    );

    if (widget.embedded) {
      return EmbeddedScreenShell(
        title: '외부 도구 연결',
        actions: [
          IconButton(
            tooltip: '새로고침',
            color: AppChrome.primaryActionNavy,
            onPressed: _refreshing ? null : _refreshStatus,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppChrome.primaryActionNavy,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
        child: body,
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppChrome.topBarBackground,
        foregroundColor: AppChrome.topBarForeground,
        surfaceTintColor: Colors.transparent,
        title: const Text('외부 도구 연결'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _refreshing ? null : _refreshStatus,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.configured,
    required this.connected,
    required this.onConnect,
    required this.onDisconnect,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool configured;
  final bool connected;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final trailing = connected
        ? const Text('연결됨', style: TextStyle(color: Colors.green))
        : Text(configured ? '미연결' : '서버 미설정');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: connected && onDisconnect != null
            ? onDisconnect
            : (!connected && configured ? onConnect : null),
      ),
    );
  }
}
