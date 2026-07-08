import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../push/services/web_push_scheduler.dart';
import '../../quotes/services/notification_service.dart';
import '../models/todo_category.dart';
import '../models/todo_item.dart';
import '../services/todo_storage_service.dart';

final todoStorageProvider = Provider((_) => TodoStorageService());

const _uuid = Uuid();

final todoCategoriesProvider =
    AsyncNotifierProvider<TodoCategoriesNotifier, List<TodoCategory>>(
        TodoCategoriesNotifier.new);

class TodoCategoriesNotifier extends AsyncNotifier<List<TodoCategory>> {
  @override
  Future<List<TodoCategory>> build() async {
    final cats = await ref.read(todoStorageProvider).loadCategories();
    if (kIsWeb) {
      Future(() async {
        final items = await ref.read(todoStorageProvider).loadItems();
        await WebPushScheduler.scheduleAllCategories(cats, items);
      });
    }
    return cats;
  }

  Future<void> _persist(List<TodoCategory> list) async {
    state = AsyncData(list);
    await ref.read(todoStorageProvider).saveCategories(list);
  }

  Future<TodoCategory> add(String name, int colorIndex) async {
    final list = state.value ?? const <TodoCategory>[];
    final now = DateTime.now();
    final c = TodoCategory(
      id: _uuid.v4(),
      name: name,
      colorIndex: colorIndex,
      createdAt: now,
      updatedAt: now,
      order: list.length,
    );
    await _persist([...list, c]);
    return c;
  }

  Future<void> save(TodoCategory updated) async {
    final list = (state.value ?? const <TodoCategory>[])
        .map((c) => c.id == updated.id ? updated : c)
        .toList();
    await _persist(list);
    if (kIsWeb) {
      final items = (ref.read(todoItemsProvider).value ?? const <TodoItem>[])
          .where((i) => i.categoryId == updated.id)
          .toList();
      await WebPushScheduler.scheduleCategory(updated, items);
    }
  }

  /// 주어진 ID 순서대로 order = 0,1,2,... 재할당
  Future<void> reorder(List<String> orderedIds) async {
    final list = [...(state.value ?? const <TodoCategory>[])];
    final byId = {for (final c in list) c.id: c};
    final updated = <TodoCategory>[];
    for (int i = 0; i < orderedIds.length; i++) {
      final c = byId[orderedIds[i]];
      if (c != null) {
        updated.add(c.copyWith(order: i, updatedAt: DateTime.now()));
        byId.remove(orderedIds[i]);
      }
    }
    updated.addAll(byId.values);
    await _persist(updated);
  }

  Future<void> toggleCollapsed(String id) async {
    final list = (state.value ?? const <TodoCategory>[]).map((c) {
      if (c.id != id) return c;
      return c.copyWith(collapsed: !c.collapsed, updatedAt: DateTime.now());
    }).toList();
    await _persist(list);
  }

  Future<void> remove(String id) async {
    // 카테고리 삭제 시 그 카테고리의 항목들도 함께 삭제 + 알림 취소
    await ref.read(todoItemsProvider.notifier).removeByCategory(id);
    if (kIsWeb) await WebPushScheduler.cancelCategory(id);
    final list = (state.value ?? const <TodoCategory>[])
        .where((c) => c.id != id)
        .toList();
    await _persist(list);
  }
}

final todoItemsProvider =
    AsyncNotifierProvider<TodoItemsNotifier, List<TodoItem>>(
        TodoItemsNotifier.new);

class TodoItemsNotifier extends AsyncNotifier<List<TodoItem>> {
  @override
  Future<List<TodoItem>> build() async {
    final items = await ref.read(todoStorageProvider).loadItems();
    // 웹: 앱 시작/복원 시 할일 알림 큐 동기화
    if (kIsWeb) {
      Future(() => WebPushScheduler.scheduleAllTodos(items));
    }
    return items;
  }

  Future<void> _persist(List<TodoItem> list) async {
    state = AsyncData(list);
    await ref.read(todoStorageProvider).saveItems(list);
  }

  Future<TodoItem> add(TodoItem draft) async {
    final existing = state.value ?? const <TodoItem>[];
    final inCat = existing.where((i) => i.categoryId == draft.categoryId);
    final minOrder = inCat.isEmpty
        ? 0
        : inCat.map((i) => i.order).reduce((a, b) => a < b ? a : b);
    final now = DateTime.now();
    final item = TodoItem(
      id: _uuid.v4(),
      categoryId: draft.categoryId,
      text: draft.text,
      repeat: draft.repeat,
      weekDays: draft.weekDays,
      monthDay: draft.monthDay,
      deadline: draft.deadline,
      notifyEnabled: draft.notifyEnabled,
      notifyDate: draft.notifyDate,
      notifyHour: draft.notifyHour,
      notifyMinute: draft.notifyMinute,
      createdAt: now,
      updatedAt: now,
      order: minOrder - 1,
    );
    await _persist([...existing, item]);
    await _scheduleNotifications(item);
    return item;
  }

  /// 카테고리 내 항목들을 주어진 ID 순서대로 재정렬.
  Future<void> reorderInCategory(
      String categoryId, List<String> orderedIds) async {
    final list = [...(state.value ?? const <TodoItem>[])];
    final byId = {for (final i in list) i.id: i};
    final updated = <TodoItem>[];
    for (int i = 0; i < orderedIds.length; i++) {
      final item = byId[orderedIds[i]];
      if (item != null && item.categoryId == categoryId) {
        updated.add(item.copyWith(order: i, updatedAt: DateTime.now()));
        byId.remove(orderedIds[i]);
      }
    }
    updated.addAll(byId.values);
    await _persist(updated);
  }

  Future<void> save(TodoItem updated) async {
    final list = (state.value ?? const <TodoItem>[])
        .map((i) => i.id == updated.id ? updated : i)
        .toList();
    await _persist(list);
    await _cancelNotifications(updated);
    await _scheduleNotifications(updated);
  }

  /// 항목을 다른 카테고리로 이동 (드래그). 대상 카테고리 맨 아래로 배치.
  Future<void> moveToCategory(String itemId, String targetCategoryId) async {
    final list = state.value ?? const <TodoItem>[];
    final idx = list.indexWhere((i) => i.id == itemId);
    if (idx < 0) return;
    final item = list[idx];
    if (item.categoryId == targetCategoryId) return;
    // 대상 카테고리에서 가장 큰 order + 1 (맨 아래)
    final targetItems = list.where((i) => i.categoryId == targetCategoryId);
    final maxOrder = targetItems.isEmpty
        ? 0
        : targetItems.map((i) => i.order).reduce((a, b) => a > b ? a : b) + 1;
    final moved = TodoItem(
      id: item.id,
      categoryId: targetCategoryId,
      text: item.text,
      repeat: item.repeat,
      weekDays: item.weekDays,
      monthDay: item.monthDay,
      deadline: item.deadline,
      notifyEnabled: item.notifyEnabled,
      notifyDate: item.notifyDate,
      notifyHour: item.notifyHour,
      notifyMinute: item.notifyMinute,
      createdAt: item.createdAt,
      updatedAt: DateTime.now(),
      completions: item.completions,
      order: maxOrder,
    );
    final newList = [...list];
    newList[idx] = moved;
    await _persist(newList);
  }

  /// 드래그 드롭: source 를 target 의 카테고리/위치(앞)에 삽입. 카테고리가
  /// 같으면 단순 순서변경, 다르면 카테고리까지 이동.
  Future<void> dropBeforeItem(String sourceId, String targetId) async {
    if (sourceId == targetId) return;
    final list = state.value ?? const <TodoItem>[];
    final src = list.where((i) => i.id == sourceId).firstOrNull;
    final tgt = list.where((i) => i.id == targetId).firstOrNull;
    if (src == null || tgt == null) return;

    // 대상 카테고리 항목들 (source 제외) 을 현재 order 순으로
    final catItems = list
        .where((i) => i.categoryId == tgt.categoryId && i.id != sourceId)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final insertIdx = catItems.indexWhere((i) => i.id == targetId);
    if (insertIdx < 0) return;

    final now = DateTime.now();
    final movedSrc = TodoItem(
      id: src.id,
      categoryId: tgt.categoryId,
      text: src.text,
      repeat: src.repeat,
      weekDays: src.weekDays,
      monthDay: src.monthDay,
      deadline: src.deadline,
      notifyEnabled: src.notifyEnabled,
      notifyDate: src.notifyDate,
      notifyHour: src.notifyHour,
      notifyMinute: src.notifyMinute,
      createdAt: src.createdAt,
      updatedAt: now,
      completions: src.completions,
      order: 0, // 아래에서 재할당
    );
    final newCatSeq = [...catItems]..insert(insertIdx, movedSrc);
    final idMap = {
      for (int i = 0; i < newCatSeq.length; i++)
        newCatSeq[i].id: newCatSeq[i].copyWith(order: i, updatedAt: now),
    };
    // movedSrc 는 copyWith 가 categoryId 를 못 바꾸니 따로 처리
    idMap[sourceId] = TodoItem(
      id: movedSrc.id,
      categoryId: movedSrc.categoryId,
      text: movedSrc.text,
      repeat: movedSrc.repeat,
      weekDays: movedSrc.weekDays,
      monthDay: movedSrc.monthDay,
      deadline: movedSrc.deadline,
      notifyEnabled: movedSrc.notifyEnabled,
      notifyDate: movedSrc.notifyDate,
      notifyHour: movedSrc.notifyHour,
      notifyMinute: movedSrc.notifyMinute,
      createdAt: movedSrc.createdAt,
      updatedAt: now,
      completions: movedSrc.completions,
      order: insertIdx,
    );
    // 재할당 후 전체 리스트 합치기
    final newList = list.map((i) => idMap[i.id] ?? i).toList();
    await _persist(newList);
  }

  Future<void> toggleComplete(String id) async {
    final list = state.value ?? const <TodoItem>[];
    final idx = list.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    final item = list[idx];
    final now = DateTime.now();
    List<DateTime> newCompletions;
    if (item.isCompletedNow) {
      // 오늘 완료 취소
      newCompletions = [...item.completions];
      if (newCompletions.isNotEmpty) newCompletions.removeLast();
    } else {
      newCompletions = [...item.completions, now];
    }
    final updated =
        item.copyWith(completions: newCompletions, updatedAt: DateTime.now());
    final newList = [...list];
    newList[idx] = updated;
    await _persist(newList);
    // 즉시(once) 완료/취소 시 알림 등록 상태도 갱신 (완료되면 큐에서 제거)
    if (kIsWeb) await WebPushScheduler.scheduleTodo(updated);
  }

  /// 특정 완료 기록 1건 삭제 (캘린더에서 사용).
  /// 항목 자체는 유지하고 해당 시각의 완료 이력만 제거.
  /// 즉시(once) 항목이라 완료 제거로 미완료가 되면 알림/목록에 다시 나타남.
  Future<void> removeCompletion(String id, DateTime completedAt) async {
    final list = state.value ?? const <TodoItem>[];
    final idx = list.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    final item = list[idx];
    final newCompletions = [...item.completions];
    // 동일 시각 1건만 제거 (밀리초까지 일치하는 항목)
    final removeIdx = newCompletions.indexWhere((c) =>
        c.isAtSameMomentAs(completedAt));
    if (removeIdx < 0) return;
    newCompletions.removeAt(removeIdx);
    final updated =
        item.copyWith(completions: newCompletions, updatedAt: DateTime.now());
    final newList = [...list];
    newList[idx] = updated;
    await _persist(newList);
    if (kIsWeb) await WebPushScheduler.scheduleTodo(updated);
  }

  /// 특정 날짜에 완료 기록을 추가한다 (캘린더에서 지난 날짜의 미완료 항목 체크용).
  /// 그 날 이미 완료했으면 무시. 시각은 그 날짜의 현재 시:분:초로 기록.
  Future<void> completeOnDate(String id, DateTime date) async {
    final list = state.value ?? const <TodoItem>[];
    final idx = list.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    final item = list[idx];
    if (item.completions.any((c) => _sameDay(c, date))) return;
    final now = DateTime.now();
    final ts = DateTime(
        date.year, date.month, date.day, now.hour, now.minute, now.second);
    final newCompletions = [...item.completions, ts]
      ..sort((a, b) => a.compareTo(b));
    final updated =
        item.copyWith(completions: newCompletions, updatedAt: now);
    final newList = [...list];
    newList[idx] = updated;
    await _persist(newList);
    if (kIsWeb) await WebPushScheduler.scheduleTodo(updated);
  }

  Future<void> remove(String id) async {
    final list = state.value ?? const <TodoItem>[];
    final target = list.where((i) => i.id == id).firstOrNull;
    if (target != null) await _cancelNotifications(target);
    await _persist(list.where((i) => i.id != id).toList());
  }

  Future<void> removeByCategory(String categoryId) async {
    final list = state.value ?? const <TodoItem>[];
    for (final i in list.where((i) => i.categoryId == categoryId)) {
      await _cancelNotifications(i);
    }
    await _persist(list.where((i) => i.categoryId != categoryId).toList());
  }

  Future<void> _cancelNotifications(TodoItem item) async {
    await NotificationService.cancel(item.notificationId());
    for (int d = 1; d <= 7; d++) {
      await NotificationService.cancel(item.notificationId(d));
    }
    if (kIsWeb) await WebPushScheduler.cancelTodo(item.id);
  }

  Future<void> _scheduleNotifications(TodoItem item) async {
    // 웹: 백엔드 스케줄러 큐에 등록 (완료/장기목표/off 는 내부에서 걸러짐)
    if (kIsWeb) await WebPushScheduler.scheduleTodo(item);
    switch (item.repeat) {
      case TodoRepeat.longterm:
        return; // 장기 목표는 알림 없음
      case TodoRepeat.once:
        if (item.notifyEnabled) {
          final d = item.notifyDate ?? DateTime.now();
          final when = DateTime(d.year, d.month, d.day, item.notifyHour,
              item.notifyMinute);
          await NotificationService.scheduleTodoOnce(
            id: item.notificationId(),
            title: '🗒️ 할 일 알림',
            body: item.text,
            when: when,
          );
        }
        return;
      case TodoRepeat.daily:
        await NotificationService.scheduleTodoDaily(
          id: item.notificationId(),
          title: '🗒️ 오늘의 할 일',
          body: item.text,
          hour: item.notifyHour,
          minute: item.notifyMinute,
        );
        break;
      case TodoRepeat.weekly:
        for (final day in item.weekDays) {
          await NotificationService.scheduleTodoWeekly(
            id: item.notificationId(day),
            title: '🗒️ 이번주 할 일',
            body: item.text,
            weekDay: day,
            hour: item.notifyHour,
            minute: item.notifyMinute,
          );
        }
        break;
      case TodoRepeat.monthly:
        if (item.monthDay != null) {
          await NotificationService.scheduleTodoMonthly(
            id: item.notificationId(),
            title: '🗒️ 이번달 할 일',
            body: item.text,
            dayOfMonth: item.monthDay!,
            hour: item.notifyHour,
            minute: item.notifyMinute,
          );
        }
        break;
    }
  }
}

/// 카테고리별로 그룹화된 항목 (카테고리 순서대로)
/// 완료된 항목은 목록에서 제외 → 완료 기록 캘린더에서만 확인.
/// - 수시(once)·장기목표(longterm): 완료하면 영구히 사라짐.
/// - 매일/주간/월간 반복: 완료한 그 날(주/달)에는 사라지고, 다음 주기가 되면
///   isCompletedNow 가 다시 false 가 되어 목록에 자동 재생성된다.
final todoItemsByCategoryProvider =
    Provider<Map<String, List<TodoItem>>>((ref) {
  final items = ref.watch(todoItemsProvider).value ?? const <TodoItem>[];
  final map = <String, List<TodoItem>>{};
  for (final i in items) {
    if (i.isCompletedNow) continue;
    map.putIfAbsent(i.categoryId, () => []).add(i);
  }
  for (final entry in map.entries) {
    entry.value.sort((a, b) => a.order.compareTo(b.order));
  }
  return map;
});

/// 특정 날짜에 완료한 항목들 (완료 시각 포함). 캘린더용.
class CompletedEntry {
  final TodoItem item;
  final DateTime completedAt;
  const CompletedEntry(this.item, this.completedAt);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 날짜 → 그날 완료한 CompletedEntry 목록 (한 항목이 그날 여러 번 완료 가능).
final completionsByDayProvider =
    Provider<Map<DateTime, List<CompletedEntry>>>((ref) {
  final items = ref.watch(todoItemsProvider).value ?? const <TodoItem>[];
  final map = <DateTime, List<CompletedEntry>>{};
  for (final it in items) {
    for (final c in it.completions) {
      final key = DateTime(c.year, c.month, c.day);
      map.putIfAbsent(key, () => []).add(CompletedEntry(it, c));
    }
  }
  return map;
});

/// 선택한 날짜의 완료 항목을 카테고리별로 그룹화.
List<CompletedEntry> completionsOnDay(
    Map<DateTime, List<CompletedEntry>> byDay, DateTime day) {
  final key = DateTime(day.year, day.month, day.day);
  return byDay[key] ?? const [];
}
