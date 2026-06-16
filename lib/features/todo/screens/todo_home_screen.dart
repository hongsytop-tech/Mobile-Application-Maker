import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/todo_category.dart';
import '../models/todo_item.dart';
import '../providers/todo_providers.dart';
import 'category_edit_dialog.dart';
import 'todo_item_edit_screen.dart';

class TodoHomeScreen extends ConsumerWidget {
  const TodoHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCats = ref.watch(todoCategoriesProvider);
    final itemsByCat = ref.watch(todoItemsByCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('할 일'),
        actions: [
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
            children: sorted.map((cat) {
              final items = itemsByCat[cat.id] ?? const <TodoItem>[];
              return _CategorySection(category: cat, items: items);
            }).toList(),
          );
        },
      ),
    );
  }
}

class _CategorySection extends ConsumerWidget {
  final TodoCategory category;
  final List<TodoItem> items;

  const _CategorySection({required this.category, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(category.colorValue);
    final pending = items.where((i) => !i.isCompletedNow).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
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
                    child: Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => showCategoryEditDialog(
                      context,
                      ref,
                      category: category,
                    ),
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
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
            ...items.map((it) => _ItemTile(item: it, color: color)),
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
  }
}

class _ItemTile extends ConsumerWidget {
  final TodoItem item;
  final Color color;

  const _ItemTile({required this.item, required this.color});

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
              onChanged: (_) => ref
                  .read(todoItemsProvider.notifier)
                  .toggleComplete(item.id),
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
