import 'package:flutter/foundation.dart';

import '../../auth/services/supabase_service.dart';
import '../../quotes/models/quote.dart';
import '../../todo/models/todo_category.dart';
import '../../todo/models/todo_item.dart';

/// 개별 문구·할일 알림을 Supabase scheduled_pushes 큐(반복 규칙 1행)에 기록.
/// 웹(PWA) 전용 — 네이티브는 flutter_local_notifications 가 처리.
class WebPushScheduler {
  static const _kind = 'quote_individual';
  static const _todoKind = 'todo';
  static const _catKind = 'todo_category';

  static Future<void> scheduleQuote(Quote q) async {
    if (!kIsWeb) return;
    if (!SupabaseService.isAuthenticated) return;
    // 알림 끈 문구는 기존 행을 정리하고 종료.
    if (!q.hasSchedule) {
      await cancelQuote(q.id);
      return;
    }

    final first = _firstOccurrenceForQuote(q);
    if (first == null) {
      await cancelQuote(q.id);
      return;
    }

    final recur = <String, dynamic>{};
    if (q.notifyMode == NotifyMode.interval) {
      final mins = q.intervalMinutesTotal;
      if (mins == null) {
        await cancelQuote(q.id);
        return;
      }
      recur['mode'] = 'interval';
      recur['intervalMinutes'] = mins;
    } else {
      if (q.notifyHour == null || q.notifyMinute == null) {
        await cancelQuote(q.id);
        return;
      }
      recur['mode'] = 'daily';
      recur['hour'] = q.notifyHour;
      recur['minute'] = q.notifyMinute;
    }

    final uid = SupabaseService.currentUser!.id;
    try {
      // sent_at 은 upsert payload 에서 제외 — cron 발송 이력을 보존하기 위함.
      // 신규 insert 시에는 컬럼 default(NULL) 적용, 기존 행 update 시에는 보존.
      await SupabaseService.client.from('scheduled_pushes').upsert({
        'user_id': uid,
        'kind': _kind,
        'ref_id': q.id,
        'title': '📝 오늘의 문구',
        'body': q.text,
        'scheduled_at': first.toUtc().toIso8601String(),
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
  /// 알림 있는 문구는 등록, 없는(껐던) 문구는 기존 행 삭제 → reconcile.
  /// local 에 없는 ref_id (삭제됐는데 백엔드에 남은 고아 행) 도 정리.
  static Future<void> scheduleAll(List<Quote> quotes) async {
    if (!kIsWeb) return;
    if (!SupabaseService.isAuthenticated) return;
    await _deleteOrphans(_kind, quotes.map((q) => q.id).toSet());
    for (final q in quotes) {
      if (q.hasSchedule) {
        await scheduleQuote(q);
      } else {
        await cancelQuote(q.id);
      }
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

    // 알림 비활성/장기목표/완료된 once → 기존 행 정리하고 종료
    if (!item.notifyEnabled ||
        item.repeat == TodoRepeat.longterm ||
        (item.repeat == TodoRepeat.once && item.isCompletedNow)) {
      await cancelTodo(item.id);
      return;
    }

    final first = item.nextDeadline; // 모델의 다음 발송 시각 계산 재사용
    if (first == null) {
      await cancelTodo(item.id);
      return;
    }

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
        if (item.weekDays.isEmpty) {
          await cancelTodo(item.id);
          return;
        }
        recur['mode'] = 'weekly';
        recur['hour'] = item.notifyHour;
        recur['minute'] = item.notifyMinute;
        recur['weekdays'] = item.weekDays.toList()..sort();
        break;
      case TodoRepeat.monthly:
        if (item.monthDay == null) {
          await cancelTodo(item.id);
          return;
        }
        recur['mode'] = 'monthly';
        recur['hour'] = item.notifyHour;
        recur['minute'] = item.notifyMinute;
        recur['monthDay'] = item.monthDay;
        break;
      case TodoRepeat.longterm:
        await cancelTodo(item.id);
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
    await _deleteOrphans(_todoKind, items.map((i) => i.id).toSet());
    for (final i in items) {
      await scheduleTodo(i);
    }
  }

  // ---- 카테고리 단위 알림 ----

  /// 카테고리 매일 알림. 본문에 현재 미완료 항목들을 담는다.
  /// (본문은 앱 열 때마다 scheduleAllCategories 로 갱신됨)
  static Future<void> scheduleCategory(
      TodoCategory cat, List<TodoItem> itemsOfCat) async {
    if (!kIsWeb) return;
    if (!SupabaseService.isAuthenticated) return;
    if (!cat.notifyEnabled) {
      await cancelCategory(cat.id);
      return;
    }

    final pending =
        itemsOfCat.where((i) => !i.isCompletedNow).map((i) => i.text).toList();
    final body = pending.isEmpty
        ? '미완료 항목이 없어요. 잘하고 있어요! 🎉'
        : '미완료 ${pending.length}건\n• ${pending.take(8).join('\n• ')}'
            '${pending.length > 8 ? '\n…외 ${pending.length - 8}건' : ''}';

    final now = DateTime.now();
    DateTime first;
    Map<String, dynamic> recur;
    if (cat.notifyMode == 'interval') {
      final mins = cat.notifyIntervalTotalMinutes;
      if (mins < 1) {
        await cancelCategory(cat.id);
        return;
      }
      first = now.add(Duration(minutes: mins));
      recur = {
        'mode': 'interval',
        'intervalMinutes': mins,
      };
    } else {
      // daily — 오늘 시각이 지났으면 내일
      first = DateTime(
          now.year, now.month, now.day, cat.notifyHour, cat.notifyMinute);
      if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
      recur = {
        'mode': 'daily',
        'hour': cat.notifyHour,
        'minute': cat.notifyMinute,
      };
    }

    final uid = SupabaseService.currentUser!.id;
    try {
      await SupabaseService.client.from('scheduled_pushes').upsert({
        'user_id': uid,
        'kind': _catKind,
        'ref_id': cat.id,
        'title': '📋 ${cat.name}',
        'body': body,
        'scheduled_at': first.toUtc().toIso8601String(),
        'recur': recur,
      }, onConflict: 'user_id,kind,ref_id');
    } catch (e) {
      if (kDebugMode) print('scheduleCategory upsert failed: $e');
    }
  }

  static Future<void> cancelCategory(String categoryId) async {
    if (!kIsWeb) return;
    if (!SupabaseService.isAuthenticated) return;
    final uid = SupabaseService.currentUser!.id;
    try {
      await SupabaseService.client
          .from('scheduled_pushes')
          .delete()
          .eq('user_id', uid)
          .eq('kind', _catKind)
          .eq('ref_id', categoryId);
    } catch (e) {
      if (kDebugMode) print('cancelCategory failed: $e');
    }
  }

  /// 모든 카테고리 알림 재등록 (본문 갱신 포함).
  static Future<void> scheduleAllCategories(
      List<TodoCategory> cats, List<TodoItem> allItems) async {
    if (!kIsWeb) return;
    if (!SupabaseService.isAuthenticated) return;
    await _deleteOrphans(_catKind, cats.map((c) => c.id).toSet());
    for (final c in cats) {
      final items = allItems.where((i) => i.categoryId == c.id).toList();
      await scheduleCategory(c, items);
    }
  }

  /// 백엔드에는 있는데 local 에 없는 ref_id (= 삭제된 항목의 잔재) 를 일괄 삭제.
  /// 같은 사용자/kind 의 행 중 localIds 에 없는 ref_id 를 모두 제거한다.
  static Future<void> _deleteOrphans(String kind, Set<String> localIds) async {
    if (!SupabaseService.isAuthenticated) return;
    final uid = SupabaseService.currentUser!.id;
    try {
      final rows = await SupabaseService.client
          .from('scheduled_pushes')
          .select('ref_id')
          .eq('user_id', uid)
          .eq('kind', kind);
      final orphans = (rows as List)
          .map((r) => r['ref_id'] as String?)
          .whereType<String>()
          .where((id) => !localIds.contains(id))
          .toList();
      if (orphans.isEmpty) return;
      await SupabaseService.client
          .from('scheduled_pushes')
          .delete()
          .eq('user_id', uid)
          .eq('kind', kind)
          .inFilter('ref_id', orphans);
      if (kDebugMode) {
        print('Deleted ${orphans.length} orphan(s) for kind=$kind');
      }
    } catch (e) {
      if (kDebugMode) print('_deleteOrphans($kind) failed: $e');
    }
  }
}
