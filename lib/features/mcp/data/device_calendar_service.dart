import 'package:flutter/foundation.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/external_item.dart';

/// Android/iOS 기기 캘린더(삼성 캘린더 포함)에서 오늘·내일 일정을 읽습니다.
class DeviceCalendarService {
  DeviceCalendarService({DeviceCalendarPlugin? plugin})
      : _plugin = plugin ?? DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;

  bool get isSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    final status = await Permission.calendarFullAccess.request();
    return status.isGranted;
  }

  Future<List<ExternalItem>> fetchUpcomingItems({int daysAhead = 2}) async {
    if (!isSupported) return [];

    final granted = await requestPermission();
    if (!granted) return [];

    final calendarsResult = await _plugin.retrieveCalendars();
    if (!calendarsResult.isSuccess || calendarsResult.data == null) return [];

    final start = DateTime.now();
    final end = start.add(Duration(days: daysAhead));
    final items = <ExternalItem>[];

    for (final cal in calendarsResult.data!) {
      final eventsResult = await _plugin.retrieveEvents(
        cal.id,
        RetrieveEventsParams(startDate: start, endDate: end),
      );
      if (!eventsResult.isSuccess || eventsResult.data == null) continue;

      for (final e in eventsResult.data!) {
        final title = (e.title ?? '').trim();
        if (title.isEmpty) continue;
        items.add(
          ExternalItem(
            source: 'device_calendar',
            externalId: e.eventId ?? '${cal.id}-${e.start?.millisecondsSinceEpoch}',
            title: title,
            description: (e.description ?? '').trim(),
            dueAt: e.start?.toIso8601String(),
            kind: 'event',
          ),
        );
      }
    }

    items.sort((a, b) => (a.dueAt ?? '').compareTo(b.dueAt ?? ''));
    return items.take(25).toList();
  }
}
