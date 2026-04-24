/// ADHD 과부하 방지 등 앱 전역 상수.
abstract final class FocusFlowLimits {
  /// 하루에 선택·활성화할 수 있는 블록(큰 덩어리) 최대 개수.
  static const int maxSelectableBlocksPerDay = 3;

  /// "딱 N분만" 빠른 시작 프리셋(분).
  static const int quickStartMinutes = 5;
}
