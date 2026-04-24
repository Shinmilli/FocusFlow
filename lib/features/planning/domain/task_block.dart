import 'task_unit.dart';

/// 사용자에게 보이는 "큰 덩어리" 한 블록. 내부는 작은 단위로 쪼개짐.
class TaskBlock {
  TaskBlock({
    required this.id,
    required this.title,
    required this.units,
    this.isSelectedForToday = false,
  });

  final String id;
  final String title;
  final List<TaskUnit> units;
  final bool isSelectedForToday;

  bool get isFullyComplete => units.isNotEmpty && units.every((u) => u.isDone);

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'units': units.map((u) => u.toJson()).toList(),
        'isSelectedForToday': isSelectedForToday,
      };

  static TaskBlock fromJson(Map<String, Object?> json) {
    final rawUnits = (json['units'] as List?) ?? const [];
    return TaskBlock(
      id: json['id'] as String,
      title: json['title'] as String,
      units: rawUnits
          .whereType<Map>()
          .map((m) => TaskUnit.fromJson(m.cast<String, Object?>()))
          .toList(),
      isSelectedForToday: (json['isSelectedForToday'] as bool?) ?? false,
    );
  }

  TaskBlock copyWith({
    String? title,
    List<TaskUnit>? units,
    bool? isSelectedForToday,
  }) {
    return TaskBlock(
      id: id,
      title: title ?? this.title,
      units: units ?? this.units,
      isSelectedForToday: isSelectedForToday ?? this.isSelectedForToday,
    );
  }
}
