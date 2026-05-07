/// `yyyy-MM-dd` 형태 계획용 날짜 키 비교·연산.
DateTime parsePlanningDateKey(String k) {
  final p = k.split('-');
  if (p.length != 3) {
    throw FormatException('Invalid dateKey', k);
  }
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String formatPlanningDateKey(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

int comparePlanningDateKeys(String a, String b) {
  return parsePlanningDateKey(a).compareTo(parsePlanningDateKey(b));
}

/// [dateKey]가 [todayKey]보다 **이전 날**이면 true (오늘·미래는 false).
bool isStrictlyPastPlanningDateKey(String dateKey, String todayKey) {
  return comparePlanningDateKeys(dateKey, todayKey) < 0;
}

String addCalendarDaysToPlanningDateKey(String dateKey, int deltaDays) {
  final d = parsePlanningDateKey(dateKey);
  final shifted = DateTime(d.year, d.month, d.day + deltaDays);
  return formatPlanningDateKey(shifted);
}

/// [todayKey]보다 이전인 키 중 가장 이른 날 (없으면 null).
String? earliestPastPlanDayKey(Iterable<String> keys, String todayKey) {
  String? best;
  for (final k in keys) {
    if (comparePlanningDateKeys(k, todayKey) >= 0) continue;
    if (best == null || comparePlanningDateKeys(k, best) < 0) {
      best = k;
    }
  }
  return best;
}
