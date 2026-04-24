import 'task_block.dart';

/// 특정 날짜의 "오늘 보여줄 것"만 담은 뷰 모델.
class DailyPlan {
  DailyPlan({
    required this.dateKey,
    required this.blocks,
  });

  /// `yyyy-MM-dd`
  final String dateKey;
  final List<TaskBlock> blocks;
}
