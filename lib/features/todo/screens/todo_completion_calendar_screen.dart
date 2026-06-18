import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/todo_category.dart';
import '../providers/todo_providers.dart';

/// 날짜별로 그날 완료한 체크리스트를 카테고리별로 모아보는 캘린더.
class TodoCompletionCalendarScreen extends ConsumerStatefulWidget {
  const TodoCompletionCalendarScreen({super.key});

  @override
  ConsumerState<TodoCompletionCalendarScreen> createState() =>
      _TodoCompletionCalendarScreenState();
}

class _TodoCompletionCalendarScreenState
    extends ConsumerState<TodoCompletionCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final byDay = ref.watch(completionsByDayProvider);
    final cats = ref.watch(todoCategoriesProvider).value ?? const <TodoCategory>[];
    final catById = {for (final c in cats) c.id: c};

    final entries = completionsOnDay(byDay, _selectedDay);
    // 카테고리별 그룹화 (카테고리 order 순)
    final grouped = <String, List<CompletedEntry>>{};
    for (final e in entries) {
      grouped.putIfAbsent(e.item.categoryId, () => []).add(e);
    }
    final catOrder = [...cats]..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      appBar: AppBar(title: const Text('완료 기록')),
      body: ListView(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
            calendarFormat: _format,
            availableCalendarFormats: const {
              CalendarFormat.month: '월',
              CalendarFormat.twoWeeks: '2주',
              CalendarFormat.week: '주',
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            onFormatChanged: (f) => setState(() => _format = f),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) => _focusedDay = focused,
            eventLoader: (day) =>
                completionsOnDay(byDay, day).isNotEmpty ? const [''] : const [],
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '${DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_selectedDay)} 완료',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('이 날 완료한 체크리스트가 없어요.',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            )
          else
            ...catOrder
                .where((c) => grouped.containsKey(c.id))
                .map((c) => _categoryGroup(c, grouped[c.id]!)),
          // 카테고리가 삭제된 항목 (catById 에 없음)
          ...grouped.entries
              .where((e) => !catById.containsKey(e.key))
              .map((e) => _categoryGroupRaw('(삭제된 카테고리)',
                  Colors.grey, e.value)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(CompletedEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('항목을 완전히 삭제할까요?'),
        content: Text(
          '"${e.item.text}"\n'
          '항목과 모든 완료 기록이 함께 삭제됩니다.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade900),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('완전 삭제')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(todoItemsProvider.notifier).remove(e.item.id);
  }

  Widget _categoryGroup(TodoCategory cat, List<CompletedEntry> list) {
    return _categoryGroupRaw(cat.name, Color(cat.colorValue), list);
  }

  Widget _categoryGroupRaw(
      String name, Color color, List<CompletedEntry> list) {
    final tf = DateFormat('HH:mm');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(name,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 6),
              Text('${list.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 6),
          ...list.map((e) => Padding(
                padding: const EdgeInsets.only(left: 18, bottom: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.item.text,
                          style: const TextStyle(fontSize: 14)),
                    ),
                    Text(tf.format(e.completedAt),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                    InkWell(
                      onTap: () => _confirmDelete(e),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.delete_outline,
                            size: 18, color: Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
