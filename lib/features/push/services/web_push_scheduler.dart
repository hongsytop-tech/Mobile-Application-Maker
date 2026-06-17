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

    // 이 문구의 옛 pending 정리 후 새로 등록
    await cancelQuote(q.id);

    final times = _computeUpcomingForQuote(q, count: _maxSchedule);
    if (times.isEmpty) return;

    final uid = SupabaseService.currentUser!.id;
    final rows = <Map<String, dynamic>>[];
    for (int i = 0; i < times.length; i++) {
      rows.add({
        'user_id': uid,
        'kind': _kind,
        'ref_id': '${q.id}#$i',
        'title': '📝 오늘의 문구',
        'body': q.text,
        'scheduled_at': times[i].toUtc().toIso8601String(),
      });
    }
    try {
      await SupabaseService.client.from('scheduled_pushes').upsert(
            rows,
            onConflict: 'user_id,kind,scheduled_at',
            ignoreDuplicates: true,
          );
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
          .like('ref_id', '$quoteId#%')
          .filter('sent_at', 'is', null);
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

  static List<DateTime> _computeUpcomingForQuote(Quote q,
      {required int count}) {
    final now = DateTime.now();
    final result = <DateTime>[];
    switch (q.notifyMode) {
      case NotifyMode.daily:
        if (q.notifyHour == null || q.notifyMinute == null) return result;
        final base = DateTime(
            now.year, now.month, now.day, q.notifyHour!, q.notifyMinute!);
        for (int i = 0; i < count; i++) {
          final c = base.add(Duration(days: i));
          if (c.isAfter(now)) result.add(c);
        }
        break;
      case NotifyMode.interval:
        final mins = q.intervalMinutesTotal;
        if (mins == null || mins < 1) return result;
        // createdAt 을 anchor 로 사용 → 양 기기 동일 시각 산출 (deterministic)
        DateTime t = q.createdAt;
        if (!t.isAfter(now)) {
          final diffMins = now.difference(t).inMinutes;
          final steps = (diffMins ~/ mins) + 1;
          t = t.add(Duration(minutes: steps * mins));
        }
        for (int i = 0; i < count; i++) {
          result.add(t);
          t = t.add(Duration(minutes: mins));
        }
        break;
    }
    return result;
  }
}
