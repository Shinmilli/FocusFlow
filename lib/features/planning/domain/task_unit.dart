/// 가장 작은 실행 단위(체크리스트 한 줄).
class TaskUnit {
  TaskUnit({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  final String id;
  final String title;
  final bool isDone;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'isDone': isDone,
      };

  static TaskUnit fromJson(Map<String, Object?> json) {
    return TaskUnit(
      id: json['id'] as String,
      title: json['title'] as String,
      isDone: (json['isDone'] as bool?) ?? false,
    );
  }

  TaskUnit copyWith({bool? isDone}) {
    return TaskUnit(
      id: id,
      title: title,
      isDone: isDone ?? this.isDone,
    );
  }
}
