import 'dart:convert';

/// 사용자별 알림 옵션 (계정에 종속).
class NotificationSettings {
  /// 방해금지 시간대 사용 여부
  final bool quietHoursEnabled;

  /// 방해금지 시작 시각 (KST)
  final int quietStartHour;
  final int quietStartMinute;

  /// 방해금지 종료 시각 (KST). start > end 이면 익일 종료로 처리.
  final int quietEndHour;
  final int quietEndMinute;

  /// 진동 사용 여부 (브라우저/OS 가 지원하는 경우에만 효과)
  final bool vibrate;

  const NotificationSettings({
    this.quietHoursEnabled = false,
    this.quietStartHour = 23,
    this.quietStartMinute = 0,
    this.quietEndHour = 8,
    this.quietEndMinute = 0,
    this.vibrate = true,
  });

  NotificationSettings copyWith({
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietStartMinute,
    int? quietEndHour,
    int? quietEndMinute,
    bool? vibrate,
  }) =>
      NotificationSettings(
        quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
        quietStartHour: quietStartHour ?? this.quietStartHour,
        quietStartMinute: quietStartMinute ?? this.quietStartMinute,
        quietEndHour: quietEndHour ?? this.quietEndHour,
        quietEndMinute: quietEndMinute ?? this.quietEndMinute,
        vibrate: vibrate ?? this.vibrate,
      );

  Map<String, dynamic> toJson() => {
        'quietHoursEnabled': quietHoursEnabled,
        'quietStartHour': quietStartHour,
        'quietStartMinute': quietStartMinute,
        'quietEndHour': quietEndHour,
        'quietEndMinute': quietEndMinute,
        'vibrate': vibrate,
      };

  factory NotificationSettings.fromJson(Map<String, dynamic> j) =>
      NotificationSettings(
        quietHoursEnabled: j['quietHoursEnabled'] as bool? ?? false,
        quietStartHour: j['quietStartHour'] as int? ?? 23,
        quietStartMinute: j['quietStartMinute'] as int? ?? 0,
        quietEndHour: j['quietEndHour'] as int? ?? 8,
        quietEndMinute: j['quietEndMinute'] as int? ?? 0,
        vibrate: j['vibrate'] as bool? ?? true,
      );

  String toJsonString() => jsonEncode(toJson());
  factory NotificationSettings.fromJsonString(String s) =>
      NotificationSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);

  String get quietStartLabel =>
      '${quietStartHour.toString().padLeft(2, '0')}:${quietStartMinute.toString().padLeft(2, '0')}';
  String get quietEndLabel =>
      '${quietEndHour.toString().padLeft(2, '0')}:${quietEndMinute.toString().padLeft(2, '0')}';
}
