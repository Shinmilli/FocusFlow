import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_mcp_bridge.dart';
import '../domain/mcp_bridge.dart';

final mcpBridgeProvider = Provider<McpBridge>((ref) => DemoMcpBridge());
