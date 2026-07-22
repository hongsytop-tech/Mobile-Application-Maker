import 'dart:convert';

class Memo {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int order;

  /// 상단 고정 시각 (null이면 미고정). 문구 메뉴와 동일한 방식.
  final DateTime? pinnedAt;

  /// 소속 폴더 id (null 이면 폴더 없음 = 루트).
  final String? folderId;

  const Memo({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.order = 0,
    this.pinnedAt,
    this.folderId,
  });

  bool get isPinned => pinnedAt != null;

  Memo copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    int? order,
    DateTime? pinnedAt,
    bool clearPin = false,
    String? folderId,
    bool clearFolder = false,
  }) =>
      Memo(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        order: order ?? this.order,
        pinnedAt: clearPin ? null : (pinnedAt ?? this.pinnedAt),
        folderId: clearFolder ? null : (folderId ?? this.folderId),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'order': order,
        'pinnedAt': pinnedAt?.toIso8601String(),
        'folderId': folderId,
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
        pinnedAt: j['pinnedAt'] == null
            ? null
            : DateTime.parse(j['pinnedAt'] as String),
        folderId: j['folderId'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());
  factory Memo.fromJsonString(String s) =>
      Memo.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
