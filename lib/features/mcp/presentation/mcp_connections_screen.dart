import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/layout/embedded_screen_shell.dart';
import '../../../app/theme/app_chrome.dart';
import '../../../core/config/api_config.dart';
import '../../auth/presentation/auth_providers.dart';
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
  bool _waking = false;
  bool _serverAwake = false;
  Timer? _keepAliveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _wakeServer(silent: true));
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    super.dispose();
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    final auth = ref.read(authApiClientProvider);
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      auth.pingHealth();
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  Future<bool> _wakeServer({bool silent = false}) async {
    if (_waking) return _serverAwake;
    setState(() => _waking = true);
    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('서버 깨우는 중… 최대 2분 걸릴 수 있어요 (Render 무료)'),
          duration: Duration(seconds: 4),
        ),
      );
    }

    final auth = ref.read(authApiClientProvider);
    var ok = false;
    for (var i = 0; i < 40; i++) {
      try {
        if (await auth.pingHealth()) {
          ok = true;
          break;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 3));
    }

    if (mounted) {
      setState(() {
        _waking = false;
        _serverAwake = ok;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? '서버 준비됐어요. 이제 Google을 연결하세요.' : '서버가 아직 안 떠요. 잠시 후 다시 시도해 주세요.'),
          ),
        );
      }
    }
    return ok;
  }

  Future<void> _refreshStatus() async {
    setState(() => _refreshing = true);
    ref.invalidate(mcpConnectionStatusProvider);
    await ref.read(mcpConnectionStatusProvider.future);
    if (mounted) setState(() => _refreshing = false);
  }

  Future<bool> _confirmOAuthGuide() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Google 연결 안내'),
        content: const SingleChildScrollView(
          child: Text(
            '1. 브라우저에서 Google 계정을 승인해요.\n\n'
            '2. 승인 후 callback 주소에서 Render 「WELCOME BACK」 로딩이 보일 수 있어요.\n'
            '   → 1~2분 그대로 기다리세요. 창을 닫지 마세요.\n\n'
            '3. 「Google Calendar 연결 완료」가 보이면 앱으로 돌아와 새로고침하세요.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('연결 시작')),
        ],
      ),
    );
    return go ?? false;
  }

  Future<void> _connect(McpOAuthProvider provider) async {
    try {
      if (!mounted) return;

      if (!_serverAwake) {
        final awake = await _wakeServer();
        if (!awake) return;
      }

      if (provider == McpOAuthProvider.google) {
        final ok = await _confirmOAuthGuide();
        if (!ok) return;
      }

      _startKeepAlive();

      final bridge = ref.read(mcpBridgeProvider);
      final url = await bridge.startOAuth(provider);
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        _stopKeepAlive();
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
          const SnackBar(
            content: Text('브라우저에서 승인 후, 로딩 화면이면 1~2분 기다려 주세요.'),
            duration: Duration(seconds: 5),
          ),
        );
        await _pollConnectionAfterOAuth(provider);
      } else {
        _stopKeepAlive();
      }
    } catch (e) {
      _stopKeepAlive();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _pollConnectionAfterOAuth(McpOAuthProvider provider) async {
    try {
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        ref.invalidate(mcpConnectionStatusProvider);
        try {
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
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '아직 미연결이에요. callback 페이지에서 「연결 완료」가 떴는지 확인하고, '
            '안 떴으면 서버 깨우기 후 Google 연결을 다시 시도해 주세요.',
          ),
          duration: Duration(seconds: 8),
        ),
      );
    } finally {
      _stopKeepAlive();
    }
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
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _serverAwake ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      size: 20,
                      color: _serverAwake ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _waking
                          ? '서버 깨우는 중…'
                          : _serverAwake
                              ? '서버 준비됨'
                              : '서버 잠듦 (Render 무료)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Google 연결 전에 서버가 켜져 있어야 해요. callback에서 WELCOME BACK이 보이면 1~2분 기다리세요.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _waking ? null : () => _wakeServer(),
                  icon: _waking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.power_settings_new, size: 18),
                  label: const Text('서버 깨우기'),
                ),
              ],
            ),
          ),
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
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text('$e'),
          data: (status) => Column(
            children: [
              _ProviderCard(
                icon: Icons.calendar_month_outlined,
                title: 'Google Calendar',
                subtitle: status.google.note ??
                    (status.google.configured
                        ? '오늘·내일 일정 가져오기'
                        : 'Render Environment에 GOOGLE_CLIENT_ID·SECRET·REDIRECT_URI 필요'),
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
        : Text(
            configured ? '미연결' : '서버 env 누락',
            style: TextStyle(color: configured ? null : Colors.orange.shade800),
          );

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
