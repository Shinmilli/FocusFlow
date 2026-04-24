import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../planning/domain/task_block.dart';
import '../../planning/domain/task_unit.dart';
import '../../user_state/domain/user_life_context.dart';
import '../domain/agent_intervention.dart';
import '../domain/ai_agent_service.dart';

class OpenAiAgentService implements AiAgentService {
  OpenAiAgentService({
    required this.apiKey,
    this.model = 'gpt-4o-mini',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _client;

  static const _endpoint = 'https://api.openai.com/v1/chat/completions';

  Future<Map<String, Object?>> _chatJson({
    required String system,
    required String user,
  }) async {
    final res = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'temperature': 0.2,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        'response_format': {'type': 'json_object'},
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('OpenAI error ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map) throw StateError('Unexpected OpenAI response');
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) throw StateError('No choices');
    final msg = (choices.first as Map)['message'];
    if (msg is! Map) throw StateError('No message');
    final content = msg['content'];
    if (content is! String) throw StateError('No content');

    final obj = jsonDecode(content);
    if (obj is! Map) throw StateError('Model did not return JSON object');
    return obj.cast<String, Object?>();
  }

  @override
  Future<List<TaskUnit>> decomposeTask({
    required String taskTitle,
    required UserLifeContext context,
  }) async {
    final sys = 'You help ADHD users execute tasks. Return only valid JSON.';
    final user = jsonEncode({
      'taskTitle': taskTitle,
      'context': {
        'sleepHours': context.sleepHours,
        'stressLevel': context.stressLevel,
        'phoneHeavyUse': context.phoneHeavyUse,
        'examPeriod': context.examPeriod,
        'burnoutRisk': context.burnoutRisk,
        'moodNote': context.moodNote,
      },
      'outputSpec': {
        'steps': 'array of 2-4 short strings, each immediately startable in <=15 minutes, concrete, with a clear done condition',
      },
      'rules': [
        'Prefer smaller first step if sleepHours < 6 or stressLevel >= 4.',
        'Avoid vague steps like "해보기", "작업하기", "공부하기".',
        'Each step must mention a concrete object/output (e.g., "목차 5개 적기", "자료 3개 링크 저장").',
        'Korean output.',
      ],
      'returnJson': {'steps': ['string']},
    });

    final obj = await _chatJson(system: sys, user: user);
    final steps = (obj['steps'] as List?)?.whereType<String>().take(4).toList() ?? const [];
    return [
      for (var i = 0; i < steps.length; i++)
        TaskUnit(id: 'llm-$i', title: steps[i]),
    ];
  }

  @override
  Future<AgentPlanProposal> buildTodayPlan({
    required UserLifeContext context,
    required List<String> userStatedTasks,
    required List<TaskBlock> currentBacklog,
  }) async {
    final sys = 'You are an agentic ADHD planning coach. Return only valid JSON.';
    final user = jsonEncode({
      'context': {
        'sleepHours': context.sleepHours,
        'stressLevel': context.stressLevel,
        'phoneHeavyUse': context.phoneHeavyUse,
        'examPeriod': context.examPeriod,
        'burnoutRisk': context.burnoutRisk,
        'moodNote': context.moodNote,
      },
      'userStatedTasks': userStatedTasks,
      'backlogTitles': currentBacklog.map((b) => b.title).toList(),
      'constraints': {
        'maxBlocksToday': 3,
        'preferTinyStart': true,
        'includeRest': true,
      },
      'returnJson': {
        'messageForUser': 'string',
        'suggestedBlocks': [
          {
            'title': 'string',
            'units': ['string'],
          }
        ],
        'actions': [
          {
            'kind': 'reprioritize|shrinkTasks|adjustReminders|suggestRest|crisisResource|encouragement',
            'summary': 'string',
          }
        ],
      },
      'rules': [
        'Korean output.',
        'suggestedBlocks length 0-3.',
        'Each unit <= 15 minutes and concrete.',
      ],
    });

    final obj = await _chatJson(system: sys, user: user);
    final msg = (obj['messageForUser'] as String?) ?? '오늘은 작은 한 단계만 해도 충분해요.';

    final suggestedRaw = (obj['suggestedBlocks'] as List?) ?? const [];
    final suggested = <TaskBlock>[];
    for (final it in suggestedRaw) {
      if (it is! Map) continue;
      final title = it['title'];
      final units = it['units'];
      if (title is! String || units is! List) continue;
      final u = units.whereType<String>().take(8).toList();
      if (u.isEmpty) continue;
      suggested.add(
        TaskBlock(
          id: 'llm-${title.hashCode}',
          title: title,
          units: [
            for (var i = 0; i < u.length; i++) TaskUnit(id: 'llm-u$i', title: u[i]),
          ],
        ),
      );
    }

    final actionsRaw = (obj['actions'] as List?) ?? const [];
    final actions = <AgentAction>[];
    for (final it in actionsRaw) {
      if (it is! Map) continue;
      final kind = it['kind'];
      final summary = it['summary'];
      if (kind is! String || summary is! String) continue;
      final k = switch (kind) {
        'reprioritize' => AgentActionKind.reprioritize,
        'shrinkTasks' => AgentActionKind.shrinkTasks,
        'adjustReminders' => AgentActionKind.adjustReminders,
        'suggestRest' => AgentActionKind.suggestRest,
        'crisisResource' => AgentActionKind.crisisResource,
        'encouragement' => AgentActionKind.encouragement,
        _ => null,
      };
      if (k == null) continue;
      actions.add(AgentAction(kind: k, summary: summary));
    }

    return AgentPlanProposal(
      messageForUser: msg,
      suggestedBlocks: suggested,
      actions: actions,
    );
  }

  @override
  Future<String> explainFailure({
    required UserLifeContext context,
    required SessionSignals signals,
  }) async {
    final sys = 'You explain execution failure patterns kindly. Return only JSON.';
    final user = jsonEncode({
      'context': {
        'sleepHours': context.sleepHours,
        'stressLevel': context.stressLevel,
        'phoneHeavyUse': context.phoneHeavyUse,
        'examPeriod': context.examPeriod,
        'burnoutRisk': context.burnoutRisk,
      },
      'signals': {
        'ignoredNotifications': signals.ignoredNotifications,
        'minutesToStart': signals.minutesToStart,
      },
      'returnJson': {
        'text': 'string',
        'nextStep': 'string',
      },
      'rules': ['Korean output.', 'Be concrete and non-judgmental.'],
    });

    final obj = await _chatJson(system: sys, user: user);
    final text = (obj['text'] as String?) ?? '';
    final next = (obj['nextStep'] as String?) ?? '';
    return [text, if (next.isNotEmpty) '다음 한 단계: $next'].where((s) => s.trim().isNotEmpty).join('\n');
  }

  @override
  Future<String> nudgeBackFromDistraction({
    required String currentTaskTitle,
    required UserLifeContext context,
  }) async {
    final sys = 'You gently nudge users back from distraction. Return only JSON.';
    final user = jsonEncode({
      'currentTaskTitle': currentTaskTitle,
      'context': {
        'sleepHours': context.sleepHours,
        'stressLevel': context.stressLevel,
        'phoneHeavyUse': context.phoneHeavyUse,
        'examPeriod': context.examPeriod,
        'burnoutRisk': context.burnoutRisk,
      },
      'returnJson': {'text': 'string'},
      'rules': ['Korean output.', 'One short paragraph, plus one concrete next action.'],
    });

    final obj = await _chatJson(system: sys, user: user);
    return (obj['text'] as String?) ?? '괜찮아요. 지금은 “다음 한 단계”만 다시 잡아볼까요?';
  }

  @override
  Future<String> summarizeToday({
    required UserLifeContext context,
    required int blocksDone,
    required int blocksTotal,
    required SessionSignals signals,
  }) async {
    final sys = 'You summarize daily execution for ADHD users. Return only JSON.';
    final user = jsonEncode({
      'context': {
        'sleepHours': context.sleepHours,
        'stressLevel': context.stressLevel,
        'phoneHeavyUse': context.phoneHeavyUse,
        'examPeriod': context.examPeriod,
        'burnoutRisk': context.burnoutRisk,
        'moodNote': context.moodNote,
      },
      'stats': {
        'blocksDone': blocksDone,
        'blocksTotal': blocksTotal,
        'minutesToStart': signals.minutesToStart,
        'distractions': signals.ignoredNotifications,
      },
      'returnJson': {
        'summary': 'string',
        'tomorrowPlan': [
          'string'
        ],
      },
      'rules': [
        'Korean output.',
        'summary: 2-4 sentences, non-judgmental.',
        'tomorrowPlan: 2-4 bullets, concrete, <=15 minutes per first step.',
      ],
    });

    final obj = await _chatJson(system: sys, user: user);
    final summary = (obj['summary'] as String?) ?? '';
    final plan = (obj['tomorrowPlan'] as List?)?.whereType<String>().toList() ?? const [];
    final text = [
      if (summary.trim().isNotEmpty) summary.trim(),
      if (plan.isNotEmpty) '내일 추천',
      ...plan.map((s) => '- $s'),
    ].where((s) => s.trim().isNotEmpty).join('\n');
    return text.isEmpty ? '오늘 기록이 더 쌓이면 요약이 정확해져요.' : text;
  }
}

