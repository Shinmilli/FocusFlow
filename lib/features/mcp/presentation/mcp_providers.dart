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
  final bridge = ref.watch(mcpBridgeProvider);
  return bridge.fetchConnectionStatus();
});
