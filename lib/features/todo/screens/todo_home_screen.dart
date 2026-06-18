import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/services/sync_manager.dart';
import '../models/todo_category.dart';
import '../models/todo_item.dart';
import '../providers/todo_providers.dart';
import 'category_edit_dialog.dart';
import 'todo_completion_calendar_screen.dart';
import 'todo_item_edit_screen.dart';

/// 당겨서 새로고침 — 클라우드에서 pull. SyncGate 가 pullCompleted 를 받아
/// provider 무효화까지 자동 처리한다.
Future<void> _pullFromCloud(WidgetRef ref) async {
  await SyncManager.instance.pullOnLogin();
}

class TodoHomeScreen extends ConsumerWidget {
  const TodoHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCats = ref.watch(todoCategoriesProvider);
    final itemsByCat = ref.watch(todoItemsByCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('To do'),
        actions: [
          IconButton(
            tooltip: '완료 기록 (캘린더)',
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TodoCompletionCalendarScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: '카테고리 추가',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => showCategoryEditDialog(context, ref),
          ),
        ],
      ),
      body: asyncCats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.create_new_folder_outlined,
                        size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      '카테고리부터 만들어 보세요.\n예: 운동, 학습, 가정, 업무 등',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () =>
                          showCategoryEditDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('첫 카테고리 만들기'),
                    ),
                  ],
                ),
              ),
            );
          }
          final sorted = [...categories]
            ..sort((a, b) => a.order.compareTo(b.order));
          return RefreshIndicator(
            // 당겨서 새로고침 → 클라우드에서 최신 데이터 가져오기 (PC 변경 즉시 반영)
            onRefresh: () => _pullFromCloud(ref),
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              buildDefaultDragHandles: false,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: sorted.length,
              onReorder: (oldIdx, newIdx) {
                if (newIdx > oldIdx) newIdx -= 1;
                final ids = sorted.map((c) => c.id).toList();
                final moved = ids.removeAt(oldIdx);
                ids.insert(newIdx, moved);
                ref.read(todoCategoriesProvider.notifier).reorder(ids);
              },
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                child: child,
              ),
              itemBuilder: (context, i) {
                final cat = sorted[i];
                final items = itemsByCat[cat.id] ?? const <TodoItem>[];
                return KeyedSubtree(
                  key: ValueKey(cat.id),
                  child: _CategorySection(
                      category: cat, items: items, sectionIndex: i),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CategorySection extends ConsumerWidget {
  final TodoCategory category;
  final List<TodoItem> items;
  final int sectionIndex;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.sectionIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(category.colorValue);
    final pending = items.where((i) => !i.isCompletedNow).length;

    return DragTarget<String>(
      // 다른 카테고리에서 끌어온 항목을 이 카테고리로 이동
      onWillAcceptWithDetails: (d) => true,
      onAcceptWithDetails: (d) {
        ref
            .read(todoItemsProvider.notifier)
            .moveToCategory(d.data, category.id);
      },
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: hovering ? color.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hovering ? color : Colors.grey.shade300,
              width: hovering ? 2 : 1,
            ),
          ),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom:
                  category.collapsed ? const Radius.circular(14) : Radius.zero,
            ),
            onTap: () => ref
                .read(todoCategoriesProvider.notifier)
                .toggleCollapsed(category.id),
            onLongPress: () => showCategoryEditDialog(
              context,
              ref,
              category: category,
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (category.notifyEnabled)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_active,
                                    size: 12, color: color),
                                const SizedBox(width: 3),
                                Text(
                                  '매일 ${category.notifyHour.toString().padLeft(2, '0')}:${category.notifyMinute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: color,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (pending > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$pending',
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                  // 펼침/접힘 아이콘
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: category.collapsed ? '펼치기' : '접기',
                    onPressed: () => ref
                        .read(todoCategoriesProvider.notifier)
                        .toggleCollapsed(category.id),
                    icon: Icon(category.collapsed
                        ? Icons.expand_more
                        : Icons.expand_less),
                  ),
                  // 카테고리 편집 메뉴
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '카테고리 편집',
                    onPressed: () => showCategoryEditDialog(
                      context,
                      ref,
                      category: category,
                    ),
                    icon: const Icon(Icons.more_horiz),
                  ),
                  // 카테고리 드래그 핸들
                  ReorderableDragStartListener(
                    index: sectionIndex,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Icon(Icons.drag_handle,
                          size: 22, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (category.collapsed)
            const SizedBox.shrink()
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Text(
                '아직 할 일이 없어요',
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorder: (oldIdx, newIdx) {
                if (newIdx > oldIdx) newIdx -= 1;
                final ids = items.map((e) => e.id).toList();
                final moved = ids.removeAt(oldIdx);
                ids.insert(newIdx, moved);
                ref
                    .read(todoItemsProvider.notifier)
                    .reorderInCategory(category.id, ids);
              },
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                elevation: 4,
                child: child,
              ),
              itemBuilder: (context, i) {
                final it = items[i];
                return KeyedSubtree(
                  key: ValueKey(it.id),
                  child: _ItemTile(item: it, color: color, index: i),
                );
              },
            ),
          if (!category.collapsed)
            Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        TodoItemEditScreen(categoryId: category.id),
                  ),
                ),
                icon: Icon(Icons.add, color: color, size: 18),
                label: Text('할 일 추가',
                    style: TextStyle(color: color)),
              ),
            ),
          ),
        ],
          ),
        );
      },
    );
  }
}

class _ItemTile extends ConsumerWidget {
  final TodoItem item;
  final Color color;
  final int index;

  const _ItemTile(
      {required this.item, required this.color, required this.index});

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TodoItem it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('이 항목을 삭제할까요?'),
        content: Text(it.text,
            maxLines: 3, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(todoItemsProvider.notifier).remove(it.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('MM.dd HH:mm');
    final done = item.isCompletedNow;
    final next = item.nextDeadline;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TodoItemEditScreen(
              categoryId: item.categoryId, item: item),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: done,
              activeColor: color,
              onChanged: (_) async {
                final wasOnce = item.repeat == TodoRepeat.once;
                final wasDone = item.isCompletedNow;
                // 토글 후 이 위젯이 unmount 될 수 있으니 messenger·notifier 를 미리 캡처
                // (unmount 된 ref 로는 read 가 동작하지 않아 실행취소가 무산되던 문제)
                final messenger = ScaffoldMessenger.of(context);
                final notifier = ref.read(todoItemsProvider.notifier);
                await notifier.toggleComplete(item.id);
                // 수시(once) 항목을 방금 "완료"로 바꾼 경우만 → 10초 Undo 스낵바
                if (!wasOnce || wasDone) return;
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 10),
                    behavior: SnackBarBehavior.floating,
                    content: Text('완료: ${item.text}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15)),
                    action: SnackBarAction(
                      label: '실행 취소',
                      onPressed: () => notifier.toggleComplete(item.id),
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style: TextStyle(
                      fontSize: 14,
                      decoration:
                          done ? TextDecoration.lineThrough : null,
                      color: done ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    children: [
                      _badge(
                        icon: Icons.repeat,
                        text: item.repeatLabel,
                        color: color,
                      ),
                      if (item.deadlineLabel != null)
                        _badge(
                          icon: Icons.flag,
                          text: item.deadlineLabel!,
                          color: (item.daysLeft ?? 1) < 0
                              ? Colors.red.shade600
                              : Colors.orange.shade800,
                        ),
                      if (next != null && !done)
                        _badge(
                          icon: Icons.alarm,
                          text: '다음 ${df.format(next)}',
                          color: Colors.grey.shade600,
                        ),
                      if (done && item.lastCompletedAt != null)
                        _badge(
                          icon: Icons.check_circle,
                          text: '완료 ${df.format(item.lastCompletedAt!)}',
                          color: Colors.green.shade700,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TodoItemEditScreen(
                      categoryId: item.categoryId, template: item),
                ),
              ),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 8),
                child: Icon(Icons.copy_outlined,
                    size: 19, color: Colors.grey.shade500),
              ),
            ),
            InkWell(
              onTap: () => _confirmDelete(context, ref, item),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 8),
                child: Icon(Icons.delete_outline,
                    size: 20, color: Colors.red.shade400),
              ),
            ),
            // 카테고리 간 이동 핸들 (1초 길게 누르면 드래그 시작)
            LongPressDraggable<String>(
              data: item.id,
              delay: const Duration(seconds: 1),
              hapticFeedbackOnStart: true,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 8)
                    ],
                  ),
                  child: Text(item.text,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              childWhenDragging: const Opacity(opacity: 0.3,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Icon(Icons.open_with, size: 20, color: Colors.grey),
                  )),
              child: Tooltip(
                message: '1초 길게 눌러 다른 카테고리로 이동',
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Icon(Icons.open_with, size: 20, color: Colors.grey),
                ),
              ),
            ),
            // 같은 카테고리 내 순서 변경 핸들
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Icon(Icons.drag_handle,
                    size: 22, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
