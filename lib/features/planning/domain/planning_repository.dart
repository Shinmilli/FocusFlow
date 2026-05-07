import 'task_block.dart';

/// 계획 저장소. 나중에 로컬 DB / 서버로 교체.
abstract class PlanningRepository {
  /// 오늘 선택된 블록만 노출 과부하 방지용으로 조회.
  Future<List<TaskBlock>> loadTodayVisibleBlocks(String dateKey);

  /// 백로그(오늘/선택한 날짜에 고르지 않은 블록).
  Future<List<TaskBlock>> loadBacklog();

  /// [dateKey]에 계획에 넣지 않은 블록(주간 화면용).
  Future<List<TaskBlock>> loadBacklogForDate(String dateKey);

  /// 오늘 블록으로 최대 [max]개까지 선택.
  Future<void> setSelectedForToday(String dateKey, List<String> blockIds);

  /// 블록 추가. "완료 전엔 다음 큰 일 추가 제한"은 [canAddNewBlock]으로 검사.
  Future<void> addBlock(TaskBlock block);

  /// 서브태스크 갱신(완료 체크 등).
  Future<void> updateBlock(TaskBlock block);

  /// 주간·과거 날짜 계획 화면용 갱신.
  ///
  /// - **오늘·미래 날짜**: 전역 블록([updateBlock])과 동일.
  /// - **이미 지난 날짜**: 그 날짜에 고정된 스냅샷만 바뀌고, 오늘 체크리스트·전역 블록은 그대로.
  Future<void> upsertPlanBlockForDate(String dateKey, TaskBlock block);

  /// 해당 날짜 계획에서 블록을 끝낸 리스트(전 단계 완료) / 할 리스트(전 단계 미완료)로 옮김.
  ///
  /// 과거 날짜는 스냅샷만 수정하고, 오늘·미래는 전역 블록을 수정한다.
  Future<void> setPlanBlockFullyCompleteForDate(String dateKey, String blockId, bool fullyComplete);

  /// 블록 삭제(오늘/백로그 목록에서 모두 제거).
  Future<void> deleteBlock(String blockId);

  /// 오늘 작업 중 "현재 작업"을 1개만 지정.
  Future<void> setCurrentTask(String? blockId);

  /// 새 블록 추가 가능 여부: 현재 진행 중 블록이 모두 완료되었을 때만 true 권장.
  Future<bool> canAddNewBlock(String dateKey);
}
