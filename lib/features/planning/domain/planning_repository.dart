import 'task_block.dart';

/// 계획 저장소. 나중에 로컬 DB / 서버로 교체.
abstract class PlanningRepository {
  /// 오늘 선택된 블록만 노출 과부하 방지용으로 조회.
  Future<List<TaskBlock>> loadTodayVisibleBlocks(String dateKey);

  /// 백로그(오늘 안 고른 일) — 한 번에 많이 보이지 않게 UI에서 접기.
  Future<List<TaskBlock>> loadBacklog();

  /// 오늘 블록으로 최대 [max]개까지 선택.
  Future<void> setSelectedForToday(String dateKey, List<String> blockIds);

  /// 블록 추가. "완료 전엔 다음 큰 일 추가 제한"은 [canAddNewBlock]으로 검사.
  Future<void> addBlock(TaskBlock block);

  /// 서브태스크 갱신(완료 체크 등).
  Future<void> updateBlock(TaskBlock block);

  /// 블록 삭제(오늘/백로그 목록에서 모두 제거).
  Future<void> deleteBlock(String blockId);

  /// 오늘 작업 중 "현재 작업"을 1개만 지정.
  Future<void> setCurrentTask(String? blockId);

  /// 새 블록 추가 가능 여부: 현재 진행 중 블록이 모두 완료되었을 때만 true 권장.
  Future<bool> canAddNewBlock(String dateKey);
}
