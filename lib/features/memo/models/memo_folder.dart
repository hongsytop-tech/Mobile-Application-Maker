import 'dart:convert';

class MemoFolder {
  final String id;
  final String name;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.order = 0,
  });

  MemoFolder copyWith({
    String? name,
    int? order,
    DateTime? updatedAt,
  }) =>
      MemoFolder(
        id: id,
        name: name ?? this.name,
        order: order ?? this.order,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MemoFolder.fromJson(Map<String, dynamic> j) => MemoFolder(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        order: j['order'] as int? ?? 0,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(
            j['updatedAt'] as String? ?? j['createdAt'] as String),
      );

  String toJsonString() => jsonEncode(toJson());
  factory MemoFolder.fromJsonString(String s) =>
      MemoFolder.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
