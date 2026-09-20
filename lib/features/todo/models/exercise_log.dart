import 'dart:convert';

/// 기본 제공 운동 종류 (자유 확장 대비 문자열로 저장).
const kExerciseTypes = <String>['수영', '스쿼트', '팔굽혀펴기'];

/// 하루의 운동 1건 (한 종류 + 세트별 횟수).
class ExerciseLog {
  final String id;

  /// 'yyyy-MM-dd' (타임존 혼선 방지 위해 날짜 문자열로 저장)
  final String dateKey;
  final String type;

  /// 세트별 횟수 (길이 = 세트 수)
  final List<int> reps;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExerciseLog({
    required this.id,
    required this.dateKey,
    required this.type,
    required this.reps,
    required this.createdAt,
    required this.updatedAt,
  });

  int get sets => reps.length;
  int get totalReps => reps.fold(0, (a, b) => a + b);

  ExerciseLog copyWith({
    String? type,
    List<int>? reps,
    DateTime? updatedAt,
  }) =>
      ExerciseLog(
        id: id,
        dateKey: dateKey,
        type: type ?? this.type,
        reps: reps ?? this.reps,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateKey': dateKey,
        'type': type,
        'reps': reps,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        id: j['id'] as String,
        dateKey: j['dateKey'] as String,
        type: j['type'] as String? ?? '',
        reps: ((j['reps'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(
            j['updatedAt'] as String? ?? j['createdAt'] as String),
      );

  String toJsonString() => jsonEncode(toJson());
  factory ExerciseLog.fromJsonString(String s) =>
      ExerciseLog.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
