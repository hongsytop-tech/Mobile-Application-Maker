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

  /// 카테고리 단위 알림 (미완료 항목 모아서 푸시).
  /// notifyMode = 'daily': notifyHour:notifyMinute 에 매일 1회
  /// notifyMode = 'interval': notifyIntervalHours/Minutes 간격마다 반복
  final bool notifyEnabled;
  final String notifyMode;
  final int notifyHour;
  final int notifyMinute;
  final int notifyIntervalHours;
  final int notifyIntervalMinutes;

  const TodoCategory({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.createdAt,
    required this.order,
    this.collapsed = false,
    this.notifyEnabled = false,
    this.notifyMode = 'daily',
    this.notifyHour = 9,
    this.notifyMinute = 0,
    this.notifyIntervalHours = 3,
    this.notifyIntervalMinutes = 0,
  });

  int get notifyIntervalTotalMinutes =>
      notifyIntervalHours * 60 + notifyIntervalMinutes;

  int get colorValue =>
      todoCategoryColors[colorIndex.clamp(0, todoCategoryColors.length - 1)];

  TodoCategory copyWith({
    String? name,
    int? colorIndex,
    int? order,
    bool? collapsed,
    bool? notifyEnabled,
    String? notifyMode,
    int? notifyHour,
    int? notifyMinute,
    int? notifyIntervalHours,
    int? notifyIntervalMinutes,
  }) {
    return TodoCategory(
      id: id,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt,
      order: order ?? this.order,
      collapsed: collapsed ?? this.collapsed,
      notifyEnabled: notifyEnabled ?? this.notifyEnabled,
      notifyMode: notifyMode ?? this.notifyMode,
      notifyHour: notifyHour ?? this.notifyHour,
      notifyMinute: notifyMinute ?? this.notifyMinute,
      notifyIntervalHours: notifyIntervalHours ?? this.notifyIntervalHours,
      notifyIntervalMinutes:
          notifyIntervalMinutes ?? this.notifyIntervalMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorIndex': colorIndex,
        'createdAt': createdAt.toIso8601String(),
        'order': order,
        'collapsed': collapsed,
        'notifyEnabled': notifyEnabled,
        'notifyMode': notifyMode,
        'notifyHour': notifyHour,
        'notifyMinute': notifyMinute,
        'notifyIntervalHours': notifyIntervalHours,
        'notifyIntervalMinutes': notifyIntervalMinutes,
      };

  factory TodoCategory.fromJson(Map<String, dynamic> j) => TodoCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        colorIndex: j['colorIndex'] as int? ?? 0,
        createdAt: DateTime.parse(j['createdAt'] as String),
        order: j['order'] as int? ?? 0,
        collapsed: j['collapsed'] as bool? ?? false,
        notifyEnabled: j['notifyEnabled'] as bool? ?? false,
        notifyMode: j['notifyMode'] as String? ?? 'daily',
        notifyHour: j['notifyHour'] as int? ?? 9,
        notifyMinute: j['notifyMinute'] as int? ?? 0,
        notifyIntervalHours: j['notifyIntervalHours'] as int? ?? 3,
        notifyIntervalMinutes: j['notifyIntervalMinutes'] as int? ?? 0,
      );

  String toJsonString() => jsonEncode(toJson());
  factory TodoCategory.fromJsonString(String s) =>
      TodoCategory.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
