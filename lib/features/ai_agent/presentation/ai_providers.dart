import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_ai_agent_service.dart';
import '../data/openai_agent_service.dart';
import '../domain/ai_agent_service.dart';

final aiAgentServiceProvider = Provider<AiAgentService>((ref) {
  const key = String.fromEnvironment('OPENAI_API_KEY');
  if (key.trim().isNotEmpty) {
    return OpenAiAgentService(apiKey: key);
  }
  return MockAiAgentService();
});
