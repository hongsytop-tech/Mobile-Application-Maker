import 'dart:convert';

import 'package:flutter/material.dart' show TimeOfDay;

enum NotifyMode { daily, interval }

class Quote {
  final String id;
  final String text;
  final DateTime createdAt;
  final bool notifyEnabled;

  /// 알림 모드 (기본: daily)
  final NotifyMode notifyMode;

  // daily 모드: 매일 이 시각에
  final int? notifyHour;
  final int? notifyMinute;

  // interval 모드: 이 간격마다
  final int? intervalHours;
  final int? intervalMinutes;

  /// 상단 고정 시각 (null이면 미고정). 여러 고정 항목 간 순서에 사용.
  final DateTime? pinnedAt;

  /// 수동 정렬 순서 (작을수록 위). 기본값은 fromJson에서 createdAt 기반 음수로 대체.
  final int order;

  const Quote({
    required this.id,
    required this.text,
    required this.createdAt,
    this.notifyEnabled = false,
    this.notifyMode = NotifyMode.daily,
    this.notifyHour,
    this.notifyMinute,
    this.intervalHours,
    this.intervalMinutes,
    this.pinnedAt,
    this.order = 0,
  });

  bool get isPinned => pinnedAt != null;

  TimeOfDay? get notifyTime {
    if (notifyHour == null || notifyMinute == null) return null;
    return TimeOfDay(hour: notifyHour!, minute: notifyMinute!);
  }

  /// 반복 간격을 분 단위로 환산. 모드가 interval이 아니거나 값이 없으면 null.
  int? get intervalMinutesTotal {
    if (notifyMode != NotifyMode.interval) return null;
    final h = intervalHours ?? 0;
    final m = intervalMinutes ?? 0;
    final total = h * 60 + m;
    return total > 0 ? total : null;
  }

  bool get hasSchedule {
    if (!notifyEnabled) return false;
    switch (notifyMode) {
      case NotifyMode.daily:
        return notifyHour != null && notifyMinute != null;
      case NotifyMode.interval:
        return intervalMinutesTotal != null;
    }
  }

  /// 알림 ID로 사용할 양의 32bit 정수
  int get notificationId => id.hashCode & 0x7fffffff;

  /// 표시용 라벨 (예: "매일 09:00", "2시간 30분마다")
  String? scheduleLabel(TimeOfDay Function(int hour, int minute)? _) {
    if (!hasSchedule) return null;
    switch (notifyMode) {
      case NotifyMode.daily:
        final h = notifyHour!.toString().padLeft(2, '0');
        final m = notifyMinute!.toString().padLeft(2, '0');
        return '매일 $h:$m';
      case NotifyMode.interval:
        final h = intervalHours ?? 0;
        final m = intervalMinutes ?? 0;
        final parts = <String>[];
        if (h > 0) parts.add('${h}시간');
        if (m > 0) parts.add('${m}분');
        return '${parts.join(' ')}마다';
    }
  }

  Quote copyWith({
    String? text,
    bool? notifyEnabled,
    NotifyMode? notifyMode,
    int? notifyHour,
    int? notifyMinute,
    int? intervalHours,
    int? intervalMinutes,
    DateTime? pinnedAt,
    int? order,
    bool clearDailyTime = false,
    bool clearInterval = false,
    bool clearPin = false,
  }) {
    return Quote(
      id: id,
      text: text ?? this.text,
      createdAt: createdAt,
      notifyEnabled: notifyEnabled ?? this.notifyEnabled,
      notifyMode: notifyMode ?? this.notifyMode,
      notifyHour: clearDailyTime ? null : (notifyHour ?? this.notifyHour),
      notifyMinute:
          clearDailyTime ? null : (notifyMinute ?? this.notifyMinute),
      intervalHours:
          clearInterval ? null : (intervalHours ?? this.intervalHours),
      intervalMinutes:
          clearInterval ? null : (intervalMinutes ?? this.intervalMinutes),
      pinnedAt: clearPin ? null : (pinnedAt ?? this.pinnedAt),
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'notifyEnabled': notifyEnabled,
        'notifyMode': notifyMode.name,
        'notifyHour': notifyHour,
        'notifyMinute': notifyMinute,
        'intervalHours': intervalHours,
        'intervalMinutes': intervalMinutes,
        'pinnedAt': pinnedAt?.toIso8601String(),
        'order': order,
      };

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        id: j['id'] as String,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        notifyEnabled: j['notifyEnabled'] as bool? ?? false,
        notifyMode: NotifyMode.values.firstWhere(
          (m) => m.name == (j['notifyMode'] as String? ?? 'daily'),
          orElse: () => NotifyMode.daily,
        ),
        notifyHour: j['notifyHour'] as int?,
        notifyMinute: j['notifyMinute'] as int?,
        intervalHours: j['intervalHours'] as int?,
        intervalMinutes: j['intervalMinutes'] as int?,
        pinnedAt: j['pinnedAt'] == null
            ? null
            : DateTime.parse(j['pinnedAt'] as String),
        order: j['order'] as int? ??
            -DateTime.parse(j['createdAt'] as String)
                .millisecondsSinceEpoch,
      );

  String toJsonString() => jsonEncode(toJson());
  factory Quote.fromJsonString(String s) =>
      Quote.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
