import 'dart:convert';

/// 책 한 권에 속한 독서 노트 한 건.
class BookNote {
  final String id;

  /// 문구 내용 (책에서 인상 깊었던 문장 또는 내 생각)
  final String content;

  /// 위치 (예: "p.42", "3장 도입부", "ch.5 §2")
  final String location;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BookNote({
    required this.id,
    required this.content,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isEmpty => content.trim().isEmpty && location.trim().isEmpty;

  BookNote copyWith({
    String? content,
    String? location,
    DateTime? updatedAt,
  }) =>
      BookNote(
        id: id,
        content: content ?? this.content,
        location: location ?? this.location,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'location': location,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory BookNote.fromJson(Map<String, dynamic> j) => BookNote(
        id: j['id'] as String,
        content: j['content'] as String? ?? '',
        location: j['location'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(
            (j['updatedAt'] as String?) ?? (j['createdAt'] as String)),
      );

  String toJsonString() => jsonEncode(toJson());
  factory BookNote.fromJsonString(String s) =>
      BookNote.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
