import 'dart:convert';

enum DiaryMode { freeform, sentences }

class Diary {
  /// 작성 대상 날짜 (시간은 00:00:00로 정규화).
  final DateTime date;
  final DiaryMode mode;
  final String freeText;
  final List<String> sentences;
  final DateTime updatedAt;

  const Diary({
    required this.date,
    required this.mode,
    this.freeText = '',
    this.sentences = const [],
    required this.updatedAt,
  });

  /// 'yyyy-MM-dd' 형식의 키
  String get dateKey => dateKeyOf(date);

  static String dateKeyOf(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime normalize(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  bool get isEmpty {
    if (mode == DiaryMode.freeform) {
      return freeText.trim().isEmpty;
    }
    return sentences.every((s) => s.trim().isEmpty);
  }

  /// 미리보기 텍스트 (캘린더 셀 등에 사용)
  String get preview {
    if (mode == DiaryMode.freeform) {
      return freeText.replaceAll('\n', ' ').trim();
    }
    return sentences
        .where((s) => s.trim().isNotEmpty)
        .map((s) => '• $s')
        .join(' ');
  }

  Diary copyWith({
    DiaryMode? mode,
    String? freeText,
    List<String>? sentences,
    DateTime? updatedAt,
  }) {
    return Diary(
      date: date,
      mode: mode ?? this.mode,
      freeText: freeText ?? this.freeText,
      sentences: sentences ?? this.sentences,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'mode': mode.name,
        'freeText': freeText,
        'sentences': sentences,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Diary.fromJson(Map<String, dynamic> j) => Diary(
        date: normalize(DateTime.parse(j['date'] as String)),
        mode: DiaryMode.values.firstWhere(
          (m) => m.name == (j['mode'] as String? ?? 'freeform'),
          orElse: () => DiaryMode.freeform,
        ),
        freeText: j['freeText'] as String? ?? '',
        sentences: (j['sentences'] as List? ?? const [])
            .map((e) => e as String)
            .toList(),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );

  String toJsonString() => jsonEncode(toJson());
  factory Diary.fromJsonString(String s) =>
      Diary.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
