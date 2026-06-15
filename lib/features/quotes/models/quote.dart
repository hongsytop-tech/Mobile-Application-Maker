import 'dart:convert';

import 'package:flutter/material.dart' show TimeOfDay;

class Quote {
  final String id;
  final String text;
  final DateTime createdAt;
  final int? notifyHour;
  final int? notifyMinute;
  final bool notifyEnabled;

  const Quote({
    required this.id,
    required this.text,
    required this.createdAt,
    this.notifyHour,
    this.notifyMinute,
    this.notifyEnabled = false,
  });

  TimeOfDay? get notifyTime {
    if (notifyHour == null || notifyMinute == null) return null;
    return TimeOfDay(hour: notifyHour!, minute: notifyMinute!);
  }

  bool get hasSchedule =>
      notifyEnabled && notifyHour != null && notifyMinute != null;

  /// 알림 ID로 사용할 양의 32bit 정수
  int get notificationId => id.hashCode & 0x7fffffff;

  Quote copyWith({
    String? text,
    int? notifyHour,
    int? notifyMinute,
    bool? notifyEnabled,
    bool clearNotifyTime = false,
  }) {
    return Quote(
      id: id,
      text: text ?? this.text,
      createdAt: createdAt,
      notifyHour: clearNotifyTime ? null : (notifyHour ?? this.notifyHour),
      notifyMinute: clearNotifyTime ? null : (notifyMinute ?? this.notifyMinute),
      notifyEnabled: notifyEnabled ?? this.notifyEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'notifyHour': notifyHour,
        'notifyMinute': notifyMinute,
        'notifyEnabled': notifyEnabled,
      };

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        id: j['id'] as String,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        notifyHour: j['notifyHour'] as int?,
        notifyMinute: j['notifyMinute'] as int?,
        notifyEnabled: j['notifyEnabled'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());
  factory Quote.fromJsonString(String s) =>
      Quote.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
