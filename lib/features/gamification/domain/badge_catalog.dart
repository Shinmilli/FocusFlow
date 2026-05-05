/// UI 노출용 — [PlayerProgress.unlockBadge]에 넣는 id와 동일해야 함.
class BadgeCatalogEntry {
  const BadgeCatalogEntry({required this.id, required this.hint});

  final String id;
  final String hint;
}

const List<BadgeCatalogEntry> kBadgeCatalog = [
  BadgeCatalogEntry(id: '첫 블록 완료', hint: '블록을 하나 끝까지 완료하면 받아요.'),
  BadgeCatalogEntry(id: '3일 연속', hint: '매일 블록 완료를 3일 연속 채우면 받아요.'),
  BadgeCatalogEntry(id: '7일 연속', hint: '매일 블록 완료를 7일 연속 채우면 받아요.'),
  BadgeCatalogEntry(id: '레벨 5', hint: '레벨이 5가 되면 받아요.'),
];
