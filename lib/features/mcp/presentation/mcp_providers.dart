import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/device_calendar_service.dart';
import '../data/focus_flow_mcp_bridge.dart';
import '../data/mcp_api_client.dart';
import '../domain/external_item.dart';
import '../domain/mcp_bridge.dart';

final deviceCalendarServiceProvider = Provider<DeviceCalendarService>((ref) {
  return DeviceCalendarService();
});

final mcpApiClientProvider = Provider<McpApiClient?>((ref) {
  if (!kApiBaseUrlConfigured) return null;
  return McpApiClient(auth: ref.watch(authApiClientProvider));
});

final mcpBridgeProvider = Provider<McpBridge>((ref) {
  return FocusFlowMcpBridge(
    api: ref.watch(mcpApiClientProvider),
    deviceCalendar: ref.watch(deviceCalendarServiceProvider),
  );
});

final mcpConnectionStatusProvider = FutureProvider<McpConnectionStatus>((ref) async {
  final api = ref.watch(mcpApiClientProvider);
  if (api == null || !kApiBaseUrlConfigured) {
    return McpConnectionStatus.offline();
  }

  try {
    return await api.fetchStatus();
  } on McpApiException catch (e) {
    if (e.statusCode == 401) rethrow;
    // 인증 전·일시 오류 시 공개 config로 configured만 표시.
    try {
      return await api.fetchPublicConfig();
    } catch (_) {
      rethrow;
    }
  }
});
