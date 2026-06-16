import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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
    return ref.read(todoStorageProvider).loadCategories();
  }

  Future<void> _persist(List<TodoCategory> list) async {
    state = AsyncData(list);
    await ref.read(todoStorageProvider).saveCategories(list);
  }

  Future<TodoCategory> add(String name, int colorIndex) async {
    final list = state.value ?? const <TodoCategory>[];
    final c = TodoCategory(
      id: _uuid.v4(),
      name: name,
      colorIndex: colorIndex,
      createdAt: DateTime.now(),
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
  }

  /// 주어진 ID 순서대로 order = 0,1,2,... 재할당
  Future<void> reorder(List<String> orderedIds) async {
    final list = [...(state.value ?? const <TodoCategory>[])];
    final byId = {for (final c in list) c.id: c};
    final updated = <TodoCategory>[];
    for (int i = 0; i < orderedIds.length; i++) {
      final c = byId[orderedIds[i]];
      if (c != null) {
        updated.add(c.copyWith(order: i));
        byId.remove(orderedIds[i]);
      }
    }
    updated.addAll(byId.values);
    await _persist(updated);
  }

  Future<void> toggleCollapsed(String id) async {
    final list = (state.value ?? const <TodoCategory>[]).map((c) {
      if (c.id != id) return c;
      return c.copyWith(collapsed: !c.collapsed);
    }).toList();
    await _persist(list);
  }

  Future<void> remove(String id) async {
    // 카테고리 삭제 시 그 카테고리의 항목들도 함께 삭제 + 알림 취소
    await ref.read(todoItemsProvider.notifier).removeByCategory(id);
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
    return ref.read(todoStorageProvider).loadItems();
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
      createdAt: DateTime.now(),
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
        updated.add(item.copyWith(order: i));
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
    final updated = item.copyWith(completions: newCompletions);
    final newList = [...list];
    newList[idx] = updated;
    await _persist(newList);
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
  }

  Future<void> _scheduleNotifications(TodoItem item) async {
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
final todoItemsByCategoryProvider =
    Provider<Map<String, List<TodoItem>>>((ref) {
  final items = ref.watch(todoItemsProvider).value ?? const <TodoItem>[];
  final map = <String, List<TodoItem>>{};
  for (final i in items) {
    map.putIfAbsent(i.categoryId, () => []).add(i);
  }
  // 각 카테고리 안에서 미완료 → 완료, 같은 그룹은 수동 order 순
  for (final entry in map.entries) {
    entry.value.sort((a, b) {
      final aDone = a.isCompletedNow ? 1 : 0;
      final bDone = b.isCompletedNow ? 1 : 0;
      if (aDone != bDone) return aDone - bDone;
      return a.order.compareTo(b.order);
    });
  }
  return map;
});
