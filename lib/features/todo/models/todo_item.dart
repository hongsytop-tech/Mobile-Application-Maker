import 'dart:convert';

enum TodoRepeat { once, daily, weekly, monthly, longterm }

extension TodoRepeatLabel on TodoRepeat {
  String get label => switch (this) {
        TodoRepeat.once => '즉시',
        TodoRepeat.daily => '매일',
        TodoRepeat.weekly => '주간',
        TodoRepeat.monthly => '월간',
        TodoRepeat.longterm => '장기 목표',
      };
}

const _weekDayLabels = ['', '월', '화', '수', '목', '금', '토', '일'];
String weekDayLabel(int day) =>
    _weekDayLabels[day.clamp(1, 7)];

class TodoItem {
  final String id;
  final String categoryId;
  final String text;
  final TodoRepeat repeat;

  /// 주간 반복용 — DateTime.weekday(1=Mon..7=Sun)
  final Set<int> weekDays;

  /// 월간 반복용 — 1..31
  final int? monthDay;

  /// 알림 시각 — 기본 9:00
  final int notifyHour;
  final int notifyMinute;

  /// 마감시한 (반복 주기와 별개, 날짜만 사용). 없으면 null.
  final DateTime? deadline;

  /// 알림 사용 여부
  final bool notifyEnabled;

  /// 즉시(once) 알림 날짜 (반복형은 무시). 없으면 오늘로 간주.
  final DateTime? notifyDate;

  final DateTime createdAt;

  /// 완료 이력 (오래된 순)
  final List<DateTime> completions;

  /// 같은 카테고리 내 수동 정렬 순서 (작을수록 위)
  final int order;

  const TodoItem({
    required this.id,
    required this.categoryId,
    required this.text,
    required this.repeat,
    this.weekDays = const {},
    this.monthDay,
    this.deadline,
    this.notifyEnabled = false,
    this.notifyDate,
    this.notifyHour = 9,
    this.notifyMinute = 0,
    required this.createdAt,
    this.completions = const [],
    this.order = 0,
  });

  /// 마감시한 D-day (오늘 기준). 마감 없으면 null.
  int? get daysLeft {
    if (deadline == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(deadline!.year, deadline!.month, deadline!.day);
    return d.difference(today).inDays;
  }

  String? get deadlineLabel {
    if (deadline == null) return null;
    final dateStr =
        '${deadline!.year}.${deadline!.month.toString().padLeft(2, '0')}.${deadline!.day.toString().padLeft(2, '0')}';
    final left = daysLeft;
    if (left == null) return dateStr;
    if (left > 0) return '$dateStr (D-$left)';
    if (left == 0) return '$dateStr (D-day)';
    return '$dateStr (D+${-left})';
  }

  DateTime? get lastCompletedAt =>
      completions.isEmpty ? null : completions.last;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 즉시(once)·장기목표(longterm): 한 번이라도 완료되면 true
  /// 반복: 오늘 완료한 기록이 있으면 true
  bool get isCompletedNow {
    if (completions.isEmpty) return false;
    if (repeat == TodoRepeat.once || repeat == TodoRepeat.longterm) {
      return true;
    }
    return _isSameDay(completions.last, DateTime.now());
  }


  /// 반복 항목의 다음 알림/데드라인 (반복 없으면 null)
  DateTime? get nextDeadline {
    final now = DateTime.now();
    final base =
        DateTime(now.year, now.month, now.day, notifyHour, notifyMinute);

    switch (repeat) {
      case TodoRepeat.once:
        if (!notifyEnabled) return null;
        final d = notifyDate ?? now;
        final at =
            DateTime(d.year, d.month, d.day, notifyHour, notifyMinute);
        return at.isAfter(now) ? at : null;
      case TodoRepeat.daily:
        return base.isAfter(now) ? base : base.add(const Duration(days: 1));
      case TodoRepeat.weekly:
        if (weekDays.isEmpty) return null;
        for (int offset = 0; offset < 14; offset++) {
          final candidate = base.add(Duration(days: offset));
          if (weekDays.contains(candidate.weekday) &&
              candidate.isAfter(now)) {
            return candidate;
          }
        }
        return null;
      case TodoRepeat.monthly:
        if (monthDay == null) return null;
        var year = now.year;
        var month = now.month;
        for (int i = 0; i < 13; i++) {
          final daysInMonth = DateTime(year, month + 1, 0).day;
          final day = monthDay!.clamp(1, daysInMonth);
          final candidate =
              DateTime(year, month, day, notifyHour, notifyMinute);
          if (candidate.isAfter(now)) return candidate;
          month++;
          if (month > 12) {
            month = 1;
            year++;
          }
        }
        return null;
      case TodoRepeat.longterm:
        // 장기 목표는 마감일·알림이 없는 지속 목표
        return null;
    }
  }

  String get repeatLabel {
    switch (repeat) {
      case TodoRepeat.once:
        return '즉시';
      case TodoRepeat.daily:
        return '매일 ${notifyHour.toString().padLeft(2, '0')}:${notifyMinute.toString().padLeft(2, '0')}';
      case TodoRepeat.weekly:
        if (weekDays.isEmpty) return '주간';
        final days = weekDays.toList()..sort();
        return '매주 ${days.map(weekDayLabel).join('·')}';
      case TodoRepeat.monthly:
        if (monthDay == null) return '월간';
        return '매월 ${monthDay}일';
      case TodoRepeat.longterm:
        return '장기 목표';
    }
  }

  TodoItem copyWith({
    String? text,
    TodoRepeat? repeat,
    Set<int>? weekDays,
    int? monthDay,
    DateTime? deadline,
    bool? notifyEnabled,
    DateTime? notifyDate,
    int? notifyHour,
    int? notifyMinute,
    List<DateTime>? completions,
    int? order,
    bool clearMonthDay = false,
    bool clearDeadline = false,
    bool clearNotifyDate = false,
  }) {
    return TodoItem(
      id: id,
      categoryId: categoryId,
      text: text ?? this.text,
      repeat: repeat ?? this.repeat,
      weekDays: weekDays ?? this.weekDays,
      monthDay: clearMonthDay ? null : (monthDay ?? this.monthDay),
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      notifyEnabled: notifyEnabled ?? this.notifyEnabled,
      notifyDate: clearNotifyDate ? null : (notifyDate ?? this.notifyDate),
      notifyHour: notifyHour ?? this.notifyHour,
      notifyMinute: notifyMinute ?? this.notifyMinute,
      createdAt: createdAt,
      completions: completions ?? this.completions,
      order: order ?? this.order,
    );
  }

  /// 알림 ID (요일별로 다른 ID 필요 — 주간 반복 시)
  int notificationId([int? weekDay]) {
    final key = weekDay == null ? id : '${id}_$weekDay';
    return key.hashCode & 0x7fffffff;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'text': text,
        'repeat': repeat.name,
        'weekDays': weekDays.toList(),
        'monthDay': monthDay,
        'deadline': deadline?.toIso8601String(),
        'notifyEnabled': notifyEnabled,
        'notifyDate': notifyDate?.toIso8601String(),
        'notifyHour': notifyHour,
        'notifyMinute': notifyMinute,
        'createdAt': createdAt.toIso8601String(),
        'completions': completions.map((d) => d.toIso8601String()).toList(),
        'order': order,
      };

  factory TodoItem.fromJson(Map<String, dynamic> j) => TodoItem(
        id: j['id'] as String,
        categoryId: j['categoryId'] as String,
        text: j['text'] as String,
        repeat: TodoRepeat.values.firstWhere(
          (r) => r.name == (j['repeat'] as String? ?? 'once'),
          orElse: () => TodoRepeat.once,
        ),
        weekDays: ((j['weekDays'] as List?) ?? const [])
            .map((e) => e as int)
            .toSet(),
        monthDay: j['monthDay'] as int?,
        deadline: j['deadline'] == null
            ? null
            : DateTime.parse(j['deadline'] as String),
        notifyEnabled: j['notifyEnabled'] as bool? ?? false,
        notifyDate: j['notifyDate'] == null
            ? null
            : DateTime.parse(j['notifyDate'] as String),
        notifyHour: j['notifyHour'] as int? ?? 9,
        notifyMinute: j['notifyMinute'] as int? ?? 0,
        createdAt: DateTime.parse(j['createdAt'] as String),
        completions: ((j['completions'] as List?) ?? const [])
            .map((e) => DateTime.parse(e as String))
            .toList(),
        order: j['order'] as int? ??
            -DateTime.parse(j['createdAt'] as String)
                .millisecondsSinceEpoch,
      );

  String toJsonString() => jsonEncode(toJson());
  factory TodoItem.fromJsonString(String s) =>
      TodoItem.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
