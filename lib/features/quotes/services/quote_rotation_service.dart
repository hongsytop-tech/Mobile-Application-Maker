import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/services/supabase_service.dart';
import '../../auth/services/sync_manager.dart';
import '../models/quote.dart';
import 'notification_service.dart';

enum RotationMode { dailyAtTime, interval }

extension RotationModeLabel on RotationMode {
  String get label => switch (this) {
        RotationMode.dailyAtTime => '매일 지정 시각',
        RotationMode.interval => '반복 간격',
      };
}

class QuoteRotationSettings {
  final bool enabled;
  final RotationMode mode;

  // dailyAtTime 모드: 매일 이 시각에
  final int hour;
  final int minute;

  // interval 모드: 이 간격마다
  final int intervalHours;
  final int intervalMinutes;

  /// interval 모드의 기준 시각.
  /// 미리보기/스케줄 계산에서 "now + interval" 이 아니라
  /// "anchor + N * interval" 중 now 이후 첫 시점부터 사용.
  /// → 설정 화면 재진입 시에도 다음 알림 시각이 흔들리지 않음.
  final DateTime? intervalAnchor;

  const QuoteRotationSettings({
    this.enabled = false,
    this.mode = RotationMode.dailyAtTime,
    this.hour = 9,
    this.minute = 0,
    this.intervalHours = 3,
    this.intervalMinutes = 0,
    this.intervalAnchor,
  });

  int get totalIntervalMinutes => intervalHours * 60 + intervalMinutes;

  QuoteRotationSettings copyWith({
    bool? enabled,
    RotationMode? mode,
    int? hour,
    int? minute,
    int? intervalHours,
    int? intervalMinutes,
    DateTime? intervalAnchor,
    bool clearIntervalAnchor = false,
  }) =>
      QuoteRotationSettings(
        enabled: enabled ?? this.enabled,
        mode: mode ?? this.mode,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        intervalHours: intervalHours ?? this.intervalHours,
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        intervalAnchor: clearIntervalAnchor
            ? null
            : (intervalAnchor ?? this.intervalAnchor),
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'mode': mode.name,
        'hour': hour,
        'minute': minute,
        'intervalHours': intervalHours,
        'intervalMinutes': intervalMinutes,
        if (intervalAnchor != null)
          'intervalAnchor': intervalAnchor!.toIso8601String(),
      };

  factory QuoteRotationSettings.fromJson(Map<String, dynamic> j) =>
      QuoteRotationSettings(
        enabled: j['enabled'] as bool? ?? false,
        mode: RotationMode.values.firstWhere(
          (m) => m.name == (j['mode'] as String? ?? 'dailyAtTime'),
          orElse: () => RotationMode.dailyAtTime,
        ),
        hour: j['hour'] as int? ?? 9,
        minute: j['minute'] as int? ?? 0,
        intervalHours: j['intervalHours'] as int? ?? 3,
        intervalMinutes: j['intervalMinutes'] as int? ?? 0,
        intervalAnchor: (j['intervalAnchor'] is String)
            ? DateTime.tryParse(j['intervalAnchor'] as String)
            : null,
      );

  String describe() {
    if (!enabled) return '꺼짐';
    if (mode == RotationMode.dailyAtTime) {
      final h = hour.toString().padLeft(2, '0');
      final m = minute.toString().padLeft(2, '0');
      return '매일 $h:$m';
    }
    final parts = <String>[];
    if (intervalHours > 0) parts.add('${intervalHours}시간');
    if (intervalMinutes > 0) parts.add('${intervalMinutes}분');
    return '${parts.join(' ')}마다';
  }
}

class QuoteRotationService {
  static const _settingsKey = 'quote_rotation_settings_v1';

  /// 알림 ID 범위 (다른 알림과 충돌 방지)
  static const _idBase = 1000000;

  /// 최대 미리 스케줄할 알림 개수
  static const _maxSchedule = 40;

  static Future<QuoteRotationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return const QuoteRotationSettings();
    try {
      return QuoteRotationSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const QuoteRotationSettings();
    }
  }

  /// 저장. interval 모드인데 기준 시각이 없거나 간격이 바뀌면 anchor 갱신.
  static Future<void> save(QuoteRotationSettings s) async {
    final existing = await load();
    var next = s;
    if (s.mode == RotationMode.interval) {
      final intervalChanged =
          existing.totalIntervalMinutes != s.totalIntervalMinutes;
      final modeChanged = existing.mode != s.mode;
      if (next.intervalAnchor == null || intervalChanged || modeChanged) {
        next = s.copyWith(intervalAnchor: DateTime.now());
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(next.toJson()));
    SyncManager.instance.markDirty();
  }

  /// 기존 순환 알림 모두 취소 후, enabled면 다시 스케줄.
  /// 문구 변경/설정 변경/앱 시작 시 호출.
  ///
  /// 웹(PWA): Supabase scheduled_pushes 테이블에 기록 → 백엔드 스케줄러가 발송
  /// 네이티브(APK): flutter_local_notifications 로 로컬 예약
  static Future<void> reschedule(List<Quote> quotes) async {
    if (kIsWeb) {
      await _rescheduleWeb(quotes);
      return;
    }
    await _cancelAll();
    if (!NotificationService.supported) return;
    final s = await load();
    if (!s.enabled || quotes.isEmpty) return;

    final times = _computeUpcoming(s, count: _maxSchedule);
    for (int i = 0; i < times.length; i++) {
      final t = times[i];
      final idx = _quoteIndexFor(s, t.when, quotes.length);
      final q = quotes[idx];
      await NotificationService.scheduleQuoteRotation(
        id: _idBase + i,
        title: '📖 오늘의 문구  ·  ${idx + 1} / ${quotes.length}',
        body: q.text,
        when: t.when,
      );
    }
  }

  static Future<void> _rescheduleWeb(List<Quote> quotes) async {
    if (!SupabaseService.isAuthenticated) return;
    final uid = SupabaseService.currentUser!.id;
    final db = SupabaseService.client;

    // 기존 quote_rotation 예약 모두 삭제
    try {
      await db
          .from('scheduled_pushes')
          .delete()
          .eq('user_id', uid)
          .eq('kind', 'quote_rotation')
          .filter('sent_at', 'is', null);
    } catch (e) {
      if (kDebugMode) print('reschedule(web): delete failed: $e');
    }

    final s = await load();
    if (!s.enabled || quotes.isEmpty) return;
    final times = _computeUpcoming(s, count: _maxSchedule);
    if (times.isEmpty) return;

    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < times.length; i++) {
      final t = times[i];
      final idx = _quoteIndexFor(s, t.when, quotes.length);
      final q = quotes[idx];
      rows.add({
        'user_id': uid,
        'kind': 'quote_rotation',
        'ref_id': '$i',
        'title': '📖 오늘의 문구 · ${idx + 1} / ${quotes.length}',
        'body': q.text,
        'scheduled_at': t.when.toUtc().toIso8601String(),
      });
    }

    try {
      await db.from('scheduled_pushes').insert(rows);
    } catch (e) {
      if (kDebugMode) print('reschedule(web): insert failed: $e');
    }
  }

  static Future<void> _cancelAll() async {
    if (!NotificationService.supported) return;
    for (int i = 0; i < _maxSchedule; i++) {
      await NotificationService.cancel(_idBase + i);
    }
  }

  /// 미리보기/디버그용
  static List<({DateTime when, int index, String text})> preview({
    required List<Quote> quotes,
    required QuoteRotationSettings settings,
    int count = 6,
  }) {
    if (quotes.isEmpty || !settings.enabled) return const [];
    final times = _computeUpcoming(settings, count: count);
    return [
      for (final t in times)
        () {
          final idx = _quoteIndexFor(settings, t.when, quotes.length);
          return (when: t.when, index: idx, text: quotes[idx].text);
        }(),
    ];
  }

  // ---- 내부 ----

  static List<({DateTime when})> _computeUpcoming(
      QuoteRotationSettings s, {
      required int count}) {
    final now = DateTime.now();
    final result = <({DateTime when})>[];
    switch (s.mode) {
      case RotationMode.dailyAtTime:
        final base = DateTime(now.year, now.month, now.day, s.hour, s.minute);
        for (int offset = 0; offset < count; offset++) {
          final candidate = base.add(Duration(days: offset));
          if (candidate.isAfter(now)) result.add((when: candidate));
        }
        break;
      case RotationMode.interval:
        final mins = s.totalIntervalMinutes;
        if (mins < 1) return const [];
        // anchor 부터 interval 단위로 전진해 now 이후 첫 시점을 찾는다.
        // anchor 가 없으면 now 를 anchor 로 간주 → now + mins 부터.
        DateTime t = s.intervalAnchor ?? now;
        if (!t.isAfter(now)) {
          final diffMins = now.difference(t).inMinutes;
          final steps = (diffMins ~/ mins) + 1;
          t = t.add(Duration(minutes: steps * mins));
        }
        for (int i = 0; i < count; i++) {
          result.add((when: t));
          t = t.add(Duration(minutes: mins));
        }
        break;
    }
    return result;
  }

  static int _quoteIndexFor(
      QuoteRotationSettings s, DateTime when, int n) {
    final epoch = DateTime.utc(2026, 1, 1);
    final whenUtc = when.toUtc();
    final num index;
    switch (s.mode) {
      case RotationMode.dailyAtTime:
        index = whenUtc.difference(epoch).inDays;
        break;
      case RotationMode.interval:
        final mins = s.totalIntervalMinutes.clamp(1, 1 << 30);
        index = whenUtc.difference(epoch).inMinutes ~/ mins;
        break;
    }
    return (index.toInt() % n).abs();
  }
}
