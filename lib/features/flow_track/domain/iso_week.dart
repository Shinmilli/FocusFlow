DateTime? parseDateKey(String key) {
  if (key.trim().isEmpty) return null;
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String dateKeyFromDate(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

DateTime startOfIsoWeek(DateTime d) {
  // ISO week starts Monday.
  final date = DateTime(d.year, d.month, d.day);
  final delta = (date.weekday - DateTime.monday) % 7;
  return date.subtract(Duration(days: delta));
}

String isoWeekKey(DateTime d) {
  // ISO week algorithm:
  // Week 1 is the week with the year's first Thursday.
  final date = DateTime(d.year, d.month, d.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final year = thursday.year;
  final yearStart = DateTime(year, 1, 1);
  final week = ((thursday.difference(yearStart).inDays) ~/ 7) + 1;
  return '${year.toString().padLeft(4, '0')}-${week.toString().padLeft(2, '0')}';
}

List<DateTime> isoWeekRangeInclusive(DateTime startMonday, DateTime endMonday) {
  final out = <DateTime>[];
  var cur = startOfIsoWeek(startMonday);
  final end = startOfIsoWeek(endMonday);
  while (!cur.isAfter(end)) {
    out.add(cur);
    cur = cur.add(const Duration(days: 7));
  }
  return out;
}

