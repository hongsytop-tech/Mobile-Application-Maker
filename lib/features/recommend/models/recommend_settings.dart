import 'dart:convert';

enum RecommendMode { daily, interval }

extension RecommendModeLabel on RecommendMode {
  String get label =>
      this == RecommendMode.daily ? '매일 지정 시각' : '반복 간격';
}

/// "오늘의 추천 문구" 알림 설정 (계정 동기화).
class RecommendSettings {
  final bool enabled;
  final RecommendMode mode;

  // daily 모드
  final int hour;
  final int minute;

  // interval 모드
  final int intervalHours;
  final int intervalMinutes;

  const RecommendSettings({
    this.enabled = false,
    this.mode = RecommendMode.daily,
    this.hour = 8,
    this.minute = 0,
    this.intervalHours = 6,
    this.intervalMinutes = 0,
  });

  int get totalIntervalMinutes => intervalHours * 60 + intervalMinutes;

  RecommendSettings copyWith({
    bool? enabled,
    RecommendMode? mode,
    int? hour,
    int? minute,
    int? intervalHours,
    int? intervalMinutes,
  }) =>
      RecommendSettings(
        enabled: enabled ?? this.enabled,
        mode: mode ?? this.mode,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        intervalHours: intervalHours ?? this.intervalHours,
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'mode': mode.name,
        'hour': hour,
        'minute': minute,
        'intervalHours': intervalHours,
        'intervalMinutes': intervalMinutes,
      };

  factory RecommendSettings.fromJson(Map<String, dynamic> j) =>
      RecommendSettings(
        enabled: j['enabled'] as bool? ?? false,
        mode: RecommendMode.values.firstWhere(
          (m) => m.name == (j['mode'] as String? ?? 'daily'),
          orElse: () => RecommendMode.daily,
        ),
        hour: j['hour'] as int? ?? 8,
        minute: j['minute'] as int? ?? 0,
        intervalHours: j['intervalHours'] as int? ?? 6,
        intervalMinutes: j['intervalMinutes'] as int? ?? 0,
      );

  String toJsonString() => jsonEncode(toJson());
  factory RecommendSettings.fromJsonString(String s) =>
      RecommendSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);

  String describe() {
    if (!enabled) return '꺼짐';
    if (mode == RecommendMode.daily) {
      return '매일 ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    final parts = <String>[];
    if (intervalHours > 0) parts.add('${intervalHours}시간');
    if (intervalMinutes > 0) parts.add('${intervalMinutes}분');
    return '${parts.join(' ')}마다';
  }
}

/// "오늘의 추천 책" 알림 설정 — 매일 1권이라 daily 만 지원 (계정 동기화).
class BookRecommendSettings {
  final bool enabled;
  final int hour;
  final int minute;

  const BookRecommendSettings({
    this.enabled = false,
    this.hour = 8,
    this.minute = 0,
  });

  BookRecommendSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      BookRecommendSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
      };

  factory BookRecommendSettings.fromJson(Map<String, dynamic> j) =>
      BookRecommendSettings(
        enabled: j['enabled'] as bool? ?? false,
        hour: j['hour'] as int? ?? 8,
        minute: j['minute'] as int? ?? 0,
      );

  String toJsonString() => jsonEncode(toJson());
  factory BookRecommendSettings.fromJsonString(String s) =>
      BookRecommendSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);

  String describe() => enabled
      ? '매일 ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'
      : '꺼짐';
}
