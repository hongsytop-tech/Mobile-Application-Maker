import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/highlighted_text.dart';
import '../models/todo_category.dart';
import '../providers/todo_providers.dart';

/// 키워드와 일치한, 특정 날짜에 완료된 체크리스트 1건.
class _Hit {
  final DateTime day;
  final CompletedEntry entry;
  const _Hit(this.day, this.entry);
}

/// To do 완료 기록 키워드 검색.
/// 체크리스트 내용에 키워드가 포함된 항목을, 완료한 날짜별로 묶어 보여준다.
class TodoSearchScreen extends ConsumerStatefulWidget {
  const TodoSearchScreen({super.key});

  @override
  ConsumerState<TodoSearchScreen> createState() => _TodoSearchScreenState();
}

class _TodoSearchScreenState extends ConsumerState<TodoSearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 완료 기록 전체에서 키워드 일치 항목을 날짜 내림차순으로.
  List<MapEntry<DateTime, List<_Hit>>> _search(
      Map<DateTime, List<CompletedEntry>> byDay, String q) {
    final lowerQ = q.toLowerCase();
    final hitsByDay = <DateTime, List<_Hit>>{};
    byDay.forEach((day, entries) {
      for (final e in entries) {
        if (e.item.text.toLowerCase().contains(lowerQ)) {
          hitsByDay.putIfAbsent(day, () => []).add(_Hit(day, e));
        }
      }
    });
    final sortedDays = hitsByDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    return [
      for (final d in sortedDays)
        MapEntry(
            d,
            hitsByDay[d]!
              ..sort((a, b) =>
                  b.entry.completedAt.compareTo(a.entry.completedAt))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final byDay = ref.watch(completionsByDayProvider);
    final cats =
        ref.watch(todoCategoriesProvider).value ?? const <TodoCategory>[];
    final catById = {for (final c in cats) c.id: c};
    final q = _query.trim();
    final results = q.isEmpty
        ? const <MapEntry<DateTime, List<_Hit>>>[]
        : _search(byDay, q);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '완료한 체크리스트 검색',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _ctrl.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: q.isEmpty
          ? _hint('검색어를 입력하세요.')
          : results.isEmpty
              ? _hint('"$q" 가 포함된 완료 기록이 없어요.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _DayCard(
                    day: results[i].key,
                    hits: results[i].value,
                    catById: catById,
                    query: q,
                  ),
                ),
    );
  }

  Widget _hint(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
        ),
      );
}

class _DayCard extends StatelessWidget {
  final DateTime day;
  final List<_Hit> hits;
  final Map<String, TodoCategory> catById;
  final String query;

  const _DayCard({
    required this.day,
    required this.hits,
    required this.catById,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR');
    final tf = DateFormat('HH:mm');
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event, size: 14, color: primary),
              const SizedBox(width: 6),
              Text(df.format(day),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: primary)),
              const SizedBox(width: 6),
              Text('${hits.length}',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 8),
          ...hits.map((h) {
            final cat = catById[h.entry.item.categoryId];
            final color =
                cat != null ? Color(cat.colorValue) : Colors.grey;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HighlightedText(
                          h.entry.item.text,
                          query: query,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 14),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text(cat?.name ?? '(삭제된 카테고리)',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(tf.format(h.entry.completedAt),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
