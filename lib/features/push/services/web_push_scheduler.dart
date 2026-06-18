import 'package:flutter/foundation.dart';

import '../../auth/services/supabase_service.dart';
import '../../quotes/models/quote.dart';
import '../../todo/models/todo_item.dart';

/// 개별 문구·할일 알림을 Supabase scheduled_pushes 큐(반복 규칙 1행)에 기록.
/// 웹(PWA) 전용 — 네이티브는 flutter_local_notifications 가 처리.
class WebPushScheduler {
  static const _kind = 'quote_individual';
  static const _todoKind = 'todo';

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

  // ---- 할일/목표 ----

  /// 할일 알림을 큐에 기록. 반복형은 recur 규칙으로, 즉시(once)는 1회성 행으로.
  /// 완료된 항목·장기목표·알림 off 는 등록하지 않는다.
  static Future<void> scheduleTodo(TodoItem item) async {
    if (!kIsWeb) return;
    if (!SupabaseService.isAuthenticated) return;

    // 항상 기존 행 정리 후 조건 충족 시 재등록
    await cancelTodo(item.id);

    if (!item.notifyEnabled) return;
    if (item.repeat == TodoRepeat.longterm) return;
    // 즉시·장기목표는 완료되면 더 이상 알림 불필요
    if (item.repeat == TodoRepeat.once && item.isCompletedNow) return;

    final first = item.nextDeadline; // 모델의 다음 발송 시각 계산 재사용
    if (first == null) return;

    final recur = <String, dynamic>{};
    switch (item.repeat) {
      case TodoRepeat.once:
        // recur 없음 (1회성)
        break;
      case TodoRepeat.daily:
        recur['mode'] = 'daily';
        recur['hour'] = item.notifyHour;
        recur['minute'] = item.notifyMinute;
        break;
      case TodoRepeat.weekly:
        if (item.weekDays.isEmpty) return;
        recur['mode'] = 'weekly';
        recur['hour'] = item.notifyHour;
        recur['minute'] = item.notifyMinute;
        recur['weekdays'] = item.weekDays.toList()..sort();
        break;
      case TodoRepeat.monthly:
        if (item.monthDay == null) return;
        recur['mode'] = 'monthly';
        recur['hour'] = item.notifyHour;
        recur['minute'] = item.notifyMinute;
        recur['monthDay'] = item.monthDay;
        break;
      case TodoRepeat.longterm:
        return;
    }

    final uid = SupabaseService.currentUser!.id;
    try {
      await SupabaseService.client.from('scheduled_pushes').upsert({
        'user_id': uid,
        'kind': _todoKind,
        'ref_id': item.id,
        'title': '🗒️ 할 일 알림',
        'body': item.text,
        'scheduled_at': first.toUtc().toIso8601String(),
        'sent_at': null,
        'recur': recur.isEmpty ? null : recur,
      }, onConflict: 'user_id,kind,ref_id');
    } catch (e) {
      if (kDebugMode) print('scheduleTodo upsert failed: $e');
    }
  }

  static Future<void> cancelTodo(String itemId) async {
    if (!kIsWeb) return;
    if (!SupabaseService.isAuthenticated) return;
    final uid = SupabaseService.currentUser!.id;
    try {
      await SupabaseService.client
          .from('scheduled_pushes')
          .delete()
          .eq('user_id', uid)
          .eq('kind', _todoKind)
          .eq('ref_id', itemId);
    } catch (e) {
      if (kDebugMode) print('cancelTodo failed: $e');
    }
  }

  static Future<void> scheduleAllTodos(List<TodoItem> items) async {
    if (!kIsWeb) return;
    if (!SupabaseService.isAuthenticated) return;
    for (final i in items) {
      await scheduleTodo(i);
    }
  }
}
