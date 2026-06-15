/// 외부 소스(구글 캘린더, 노션, 기기 캘린더)에서 가져온 항목.
class ExternalItem {
  const ExternalItem({
    required this.source,
    required this.title,
    this.externalId = '',
    this.description = '',
    this.dueAt,
    this.kind = 'task',
  });

  final String source;
  final String externalId;
  final String title;
  final String description;
  final String? dueAt;
  final String kind;

  String get sourceLabel {
    switch (source) {
      case 'google_calendar':
        return 'Google Calendar';
      case 'notion':
        return 'Notion';
      case 'device_calendar':
        return '삼성/기기 캘린더';
      default:
        return source;
    }
  }

  String get refKey => '$source:$externalId';

  factory ExternalItem.fromJson(Map<String, dynamic> json) {
    return ExternalItem(
      source: (json['source'] ?? '').toString(),
      externalId: (json['externalId'] ?? '').toString(),
      title: (json['title'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString(),
      dueAt: json['dueAt'] as String?,
      kind: (json['kind'] ?? 'task').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        'externalId': externalId,
        'title': title,
        'description': description,
        if (dueAt != null) 'dueAt': dueAt,
        'kind': kind,
      };
}

class McpProviderStatus {
  const McpProviderStatus({
    required this.configured,
    required this.connected,
    this.note,
  });

  final bool configured;
  final bool connected;
  final String? note;
}

class McpConnectionStatus {
  const McpConnectionStatus({
    required this.google,
    required this.notion,
    required this.samsungCalendar,
  });

  final McpProviderStatus google;
  final McpProviderStatus notion;
  final McpProviderStatus samsungCalendar;

  factory McpConnectionStatus.offline() {
    const offline = McpProviderStatus(configured: false, connected: false);
    return const McpConnectionStatus(
      google: offline,
      notion: offline,
      samsungCalendar: McpProviderStatus(
        configured: true,
        connected: false,
        note: '기기에서 직접 읽어요',
      ),
    );
  }

  factory McpConnectionStatus.fromJson(Map<String, dynamic> json) {
    McpProviderStatus parse(Map<String, dynamic>? m) {
      if (m == null) return const McpProviderStatus(configured: false, connected: false);
      return McpProviderStatus(
        configured: m['configured'] == true,
        connected: m['connected'] == true,
        note: m['note'] as String?,
      );
    }

    return McpConnectionStatus(
      google: parse(json['google'] as Map<String, dynamic>?),
      notion: parse(json['notion'] as Map<String, dynamic>?),
      samsungCalendar: parse(json['samsungCalendar'] as Map<String, dynamic>?),
    );
  }
}

class McpOrganizedBlock {
  const McpOrganizedBlock({
    required this.title,
    required this.units,
    this.sourceRefs = const [],
  });

  final String title;
  final List<String> units;
  final List<String> sourceRefs;

  factory McpOrganizedBlock.fromJson(Map<String, dynamic> json) {
    return McpOrganizedBlock(
      title: (json['title'] ?? '').toString().trim(),
      units: (json['units'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      sourceRefs: (json['sourceRefs'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class McpOrganizeProposal {
  const McpOrganizeProposal({
    required this.messageForUser,
    required this.blocks,
  });

  final String messageForUser;
  final List<McpOrganizedBlock> blocks;

  factory McpOrganizeProposal.fromJson(Map<String, dynamic> json) {
    return McpOrganizeProposal(
      messageForUser: (json['messageForUser'] ?? '').toString(),
      blocks: (json['blocks'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(McpOrganizedBlock.fromJson)
          .where((b) => b.title.isNotEmpty && b.units.isNotEmpty)
          .toList(),
    );
  }
}

enum McpOAuthProvider { google, notion }
