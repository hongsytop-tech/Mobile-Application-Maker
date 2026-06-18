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
            onRefresh: () => _pullFromCloud(ref),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                for (int i = 0; i < sorted.length; i++)
                  _CategorySection(
                    key: ValueKey(sorted[i].id),
                    category: sorted[i],
                    items: itemsByCat[sorted[i].id] ?? const <TodoItem>[],
                    allCategoryIdsInOrder:
                        sorted.map((c) => c.id).toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategorySection extends ConsumerStatefulWidget {
  final TodoCategory category;
  final List<TodoItem> items;
  final List<String> allCategoryIdsInOrder;

  const _CategorySection({
    super.key,
    required this.category,
    required this.items,
    required this.allCategoryIdsInOrder,
  });

  @override
  ConsumerState<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends ConsumerState<_CategorySection> {
  bool _dragging = false;

  TodoCategory get category => widget.category;
  List<TodoItem> get items => widget.items;
  List<String> get allCategoryIdsInOrder => widget.allCategoryIdsInOrder;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.colorValue);
    final pending = items.where((i) => !i.isCompletedNow).length;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: _dragging ? 0.35 : 1.0,
      child: DragTarget<_CategoryDrag>(
      // 다른 카테고리를 끌어와 이 위치 앞에 삽입
      onWillAcceptWithDetails: (d) => d.data.id != category.id,
      onAcceptWithDetails: (d) {
        final ids = [...allCategoryIdsInOrder];
        ids.remove(d.data.id);
        final insertAt = ids.indexOf(category.id);
        ids.insert(insertAt < 0 ? ids.length : insertAt, d.data.id);
        ref.read(todoCategoriesProvider.notifier).reorder(ids);
      },
      builder: (context, catCand, _) {
        final catHovering = catCand.isNotEmpty;
        return DragTarget<String>(
          // 다른 카테고리에서 끌어온 항목만 받는다 (기존 카테고리에서 끌면 하이라이트 X)
          onWillAcceptWithDetails: (d) =>
              !items.any((i) => i.id == d.data),
          onAcceptWithDetails: (d) {
            ref
                .read(todoItemsProvider.notifier)
                .moveToCategory(d.data, category.id);
          },
          builder: (context, candidate, rejected) {
            final hovering = candidate.isNotEmpty || catHovering;
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
            // (이전 onLongPress → 편집 다이얼로그 제거. 카테고리 헤더 핸들의
            //  LongPressDraggable 과 충돌해 드래그 대신 다이얼로그가 열리던 문제.
            //  편집은 ⋯ 메뉴 아이콘으로 진입.)
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
                  // 카테고리 드래그 핸들 — 길게 눌러 위아래로 끌기
                  LongPressDraggable<_CategoryDrag>(
                    data: _CategoryDrag(category.id),
                    axis: Axis.vertical,
                    dragAnchorStrategy: (d, ctx, pos) =>
                        Offset(pos.dx - 12, 25),
                    onDragStarted: () => setState(() => _dragging = true),
                    onDragEnd: (_) => setState(() => _dragging = false),
                    onDraggableCanceled: (_, __) =>
                        setState(() => _dragging = false),
                    feedback: SizedBox(
                      width: MediaQuery.of(context).size.width - 24,
                      child: Material(
                        color: Colors.transparent,
                        elevation: 6,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: color.withOpacity(0.4), width: 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(category.name,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Icon(Icons.drag_handle,
                          size: 22, color: Colors.grey),
                    ),
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
            Column(
              children: [
                for (int i = 0; i < items.length; i++)
                  DragTarget<String>(
                    onWillAcceptWithDetails: (d) => d.data != items[i].id,
                    onAcceptWithDetails: (d) {
                      ref
                          .read(todoItemsProvider.notifier)
                          .dropBeforeItem(d.data, items[i].id);
                    },
                    builder: (context, candidate, _) {
                      final hovering = candidate.isNotEmpty;
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: hovering ? color : Colors.transparent,
                              width: hovering ? 2 : 0,
                            ),
                          ),
                        ),
                        child: _ItemTile(
                            item: items[i], color: color, index: i),
                      );
                    },
                  ),
              ],
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
      },
      ),
    );
  }
}

class _CategoryDrag {
  final String id;
  const _CategoryDrag(this.id);
}

class _ItemTile extends ConsumerStatefulWidget {
  final TodoItem item;
  final Color color;
  final int index;

  const _ItemTile(
      {required this.item, required this.color, required this.index});

  @override
  ConsumerState<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends ConsumerState<_ItemTile> {
  bool _dragging = false;

  TodoItem get item => widget.item;
  Color get color => widget.color;
  int get index => widget.index;

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
  Widget build(BuildContext context) {
    final df = DateFormat('MM.dd HH:mm');
    final done = item.isCompletedNow;
    final next = item.nextDeadline;

    final row = InkWell(
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
            // 드래그 핸들 — 길게 눌러 끌면 행 전체가 위아래로만 움직임
            LongPressDraggable<String>(
              data: item.id,
              axis: Axis.vertical,
              // 피드백의 좌측을 ListView padding(12px) 위치에 고정.
              // 손가락 X 위치와 무관하게 행 폭/위치 유지.
              dragAnchorStrategy: (d, ctx, pos) => Offset(pos.dx - 12, 25),
              onDragStarted: () => setState(() => _dragging = true),
              onDragEnd: (_) => setState(() => _dragging = false),
              onDraggableCanceled: (_, __) =>
                  setState(() => _dragging = false),
              feedback: SizedBox(
                width: MediaQuery.of(context).size.width - 24,
                child: Material(
                  color: Colors.transparent,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: color.withOpacity(0.4), width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(done ? Icons.check_box : Icons.check_box_outline_blank,
                            color: color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(item.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              childWhenDragging: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Icon(Icons.drag_handle,
                    size: 22, color: Colors.grey),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Icon(Icons.drag_handle,
                    size: 22, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );

    // 드래그 중엔 행 전체가 흐릿하게 표시되어 이동 중임을 명확히 보여줌
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: _dragging ? 0.35 : 1.0,
      child: row,
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
