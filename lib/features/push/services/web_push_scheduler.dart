import 'package:flutter/foundation.dart';

import '../../auth/services/supabase_service.dart';
import '../../quotes/models/quote.dart';

/// 개별 문구 알림(daily / interval) 을 Supabase scheduled_pushes 큐에 기록.
/// 웹(PWA) 전용 — 네이티브는 flutter_local_notifications 가 처리.
///
/// 시각 계산은 daily=고정 시각, interval=문구의 createdAt 을 anchor 로 deterministic.
/// → 양 기기가 동일 시각을 산출해 upsert ignoreDuplicates 로 멱등.
class WebPushScheduler {
  static const _maxSchedule = 40;
  static const _kind = 'quote_individual';

  static Future<void> scheduleQuote(Quote q) async {
    if (!kIsWeb) return;
    if (!q.hasSchedule) return;
    if (!SupabaseService.isAuthenticated) return;

    // 이 문구의 기존 행 정리 후 반복 규칙 1행으로 재등록
    await cancelQuote(q.id);

    final first = _firstOccurrenceForQuote(q);
    if (first == null) return;

    final recur = <String, dynamic>{};
    if (q.notifyMode == NotifyMode.interval) {
      final mins = q.intervalMinutesTotal;
      if (mins == null) return;
      recur['mode'] = 'interval';
      recur['intervalMinutes'] = mins;
    } else {
      if (q.notifyHour == null || q.notifyMinute == null) return;
      recur['mode'] = 'daily';
      recur['hour'] = q.notifyHour;
      recur['minute'] = q.notifyMinute;
    }

    final uid = SupabaseService.currentUser!.id;
    try {
      await SupabaseService.client.from('scheduled_pushes').upsert({
        'user_id': uid,
        'kind': _kind,
        'ref_id': q.id,
        'title': '📝 오늘의 문구',
        'body': q.text,
        'scheduled_at': first.toUtc().toIso8601String(),
        'sent_at': null,
        'recur': recur,
      }, onConflict: 'user_id,kind,ref_id');
    } catch (e) {
      if (kDebugMode) print('scheduleQuote upsert failed: $e');
    }
  }

  static Future<void> cancelQuote(String quoteId) async {
    if (!kIsWeb) return;
    if (!SupabaseService.isAuthenticated) return;
    final uid = SupabaseService.currentUser!.id;
    try {
      await SupabaseService.client
          .from('scheduled_pushes')
          .delete()
          .eq('user_id', uid)
          .eq('kind', _kind)
          .eq('ref_id', quoteId);
    } catch (e) {
      if (kDebugMode) print('cancelQuote failed: $e');
    }
  }

  /// 여러 문구를 한 번에 스케줄링 (앱 시작/pull 후 호출).
  static Future<void> scheduleAll(List<Quote> quotes) async {
    if (!kIsWeb) return;
    if (!SupabaseService.isAuthenticated) return;
    for (final q in quotes) {
      if (q.hasSchedule) await scheduleQuote(q);
    }
  }

  /// 첫 발송 시각 (now 이후). 이후 반복은 백엔드가 recur 로 전진시킨다.
  static DateTime? _firstOccurrenceForQuote(Quote q) {
    final now = DateTime.now();
    switch (q.notifyMode) {
      case NotifyMode.daily:
        if (q.notifyHour == null || q.notifyMinute == null) return null;
        var c = DateTime(
            now.year, now.month, now.day, q.notifyHour!, q.notifyMinute!);
        if (!c.isAfter(now)) c = c.add(const Duration(days: 1));
        return c;
      case NotifyMode.interval:
        final mins = q.intervalMinutesTotal;
        if (mins == null || mins < 1) return null;
        // createdAt 을 anchor 로 사용 → 양 기기 동일 시각 산출 (deterministic)
        DateTime t = q.createdAt;
        if (!t.isAfter(now)) {
          final diffMins = now.difference(t).inMinutes;
          final steps = (diffMins ~/ mins) + 1;
          t = t.add(Duration(minutes: steps * mins));
        }
        return t;
    }
  }
}
