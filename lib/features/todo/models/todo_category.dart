import 'dart:convert';

const todoCategoryColors = <int>[
  0xFF4F46E5, // indigo
  0xFFEC4899, // pink
  0xFFF59E0B, // amber
  0xFF10B981, // emerald
  0xFF06B6D4, // cyan
  0xFF8B5CF6, // violet
];

class TodoCategory {
  final String id;
  final String name;
  final int colorIndex;
  final DateTime createdAt;
  final int order;
  final bool collapsed;

  const TodoCategory({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.createdAt,
    required this.order,
    this.collapsed = false,
  });

  int get colorValue =>
      todoCategoryColors[colorIndex.clamp(0, todoCategoryColors.length - 1)];

  TodoCategory copyWith(
      {String? name, int? colorIndex, int? order, bool? collapsed}) {
    return TodoCategory(
      id: id,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt,
      order: order ?? this.order,
      collapsed: collapsed ?? this.collapsed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorIndex': colorIndex,
        'createdAt': createdAt.toIso8601String(),
        'order': order,
        'collapsed': collapsed,
      };

  factory TodoCategory.fromJson(Map<String, dynamic> j) => TodoCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        colorIndex: j['colorIndex'] as int? ?? 0,
        createdAt: DateTime.parse(j['createdAt'] as String),
        order: j['order'] as int? ?? 0,
        collapsed: j['collapsed'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());
  factory TodoCategory.fromJsonString(String s) =>
      TodoCategory.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
