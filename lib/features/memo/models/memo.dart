import 'dart:convert';

class Memo {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int order;

  const Memo({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.order = 0,
  });

  Memo copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    int? order,
  }) =>
      Memo(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        order: order ?? this.order,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'order': order,
      };

  factory Memo.fromJson(Map<String, dynamic> j) => Memo(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        content: j['content'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(
            j['updatedAt'] as String? ?? j['createdAt'] as String),
        order: j['order'] as int? ??
            -DateTime.parse(j['createdAt'] as String)
                .millisecondsSinceEpoch,
      );

  String toJsonString() => jsonEncode(toJson());
  factory Memo.fromJsonString(String s) =>
      Memo.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
