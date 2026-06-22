import 'dart:convert';

/// 일기 입력 모드.
/// - sentences: "일상" (예전 '문장별'). 사용자가 항목별로 적는 일상 기록.
/// - gratitude: "감사 일기". 항목별로 적는 감사 거리.
/// - freeform: 옛 '서술형'. 더 이상 새 데이터로 생성하지 않으며,
///   fromJson 단계에서 sentences 모드로 자동 마이그레이션된다.
enum DiaryMode { freeform, sentences, gratitude }

class Diary {
  /// 작성 대상 날짜 (시간은 00:00:00로 정규화).
  final DateTime date;
  final DiaryMode mode;
  final String freeText;
  final List<String> sentences;
  final List<String> gratitudes;
  final DateTime updatedAt;

  const Diary({
    required this.date,
    required this.mode,
    this.freeText = '',
    this.sentences = const [],
    this.gratitudes = const [],
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
    if (mode == DiaryMode.gratitude) {
      return gratitudes.every((s) => s.trim().isEmpty);
    }
    // sentences (옛 freeform 도 마이그레이션 후 여기로 옴)
    return sentences.every((s) => s.trim().isEmpty);
  }

  /// 미리보기 텍스트 (캘린더 셀 등에 사용)
  String get preview {
    final list = mode == DiaryMode.gratitude ? gratitudes : sentences;
    return list
        .where((s) => s.trim().isNotEmpty)
        .map((s) => '• $s')
        .join(' ');
  }

  Diary copyWith({
    DiaryMode? mode,
    String? freeText,
    List<String>? sentences,
    List<String>? gratitudes,
    DateTime? updatedAt,
  }) {
    return Diary(
      date: date,
      mode: mode ?? this.mode,
      freeText: freeText ?? this.freeText,
      sentences: sentences ?? this.sentences,
      gratitudes: gratitudes ?? this.gratitudes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'mode': mode.name,
        'freeText': freeText,
        'sentences': sentences,
        'gratitudes': gratitudes,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Diary.fromJson(Map<String, dynamic> j) {
    final modeName = j['mode'] as String? ?? 'sentences';
    var mode = DiaryMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => DiaryMode.sentences,
    );
    final freeText = j['freeText'] as String? ?? '';
    var sentences = (j['sentences'] as List? ?? const [])
        .map((e) => e as String)
        .toList();
    final gratitudes = (j['gratitudes'] as List? ?? const [])
        .map((e) => e as String)
        .toList();

    // 옛 'freeform' 데이터 → 'sentences' 로 마이그레이션.
    // 줄바꿈 단위로 잘라 빈 줄을 빼고 항목 리스트로 만든다.
    if (mode == DiaryMode.freeform) {
      mode = DiaryMode.sentences;
      if (sentences.isEmpty && freeText.trim().isNotEmpty) {
        sentences = freeText
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (sentences.isEmpty) sentences = [freeText.trim()];
      }
    }

    return Diary(
      date: normalize(DateTime.parse(j['date'] as String)),
      mode: mode,
      freeText: freeText,
      sentences: sentences,
      gratitudes: gratitudes,
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory Diary.fromJsonString(String s) =>
      Diary.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
