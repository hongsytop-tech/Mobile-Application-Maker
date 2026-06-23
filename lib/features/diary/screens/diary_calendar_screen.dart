import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../auth/services/sync_manager.dart';
import '../../../shared/widgets/scroll_to_top.dart';
import '../models/diary.dart';
import '../providers/diary_providers.dart';
import 'diary_edit_screen.dart';

class DiaryCalendarScreen extends ConsumerStatefulWidget {
  const DiaryCalendarScreen({super.key});

  @override
  ConsumerState<DiaryCalendarScreen> createState() =>
      _DiaryCalendarScreenState();
}

class _DiaryCalendarScreenState extends ConsumerState<DiaryCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = Diary.normalize(DateTime.now());
  CalendarFormat _format = CalendarFormat.month;

  void _openEditor(DateTime date) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DiaryEditScreen(date: date)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateSet = ref.watch(diaryDateSetProvider);
    final selectedDiary = ref.watch(
      diaryByDateProvider(Diary.normalize(_selectedDay)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('일기')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(_selectedDay),
        icon: Icon(selectedDiary == null ? Icons.edit : Icons.edit_note),
        label: Text(selectedDiary == null ? '일기 쓰기' : '일기 수정'),
      ),
      body: Column(
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
            startingDayOfWeek: StartingDayOfWeek.sunday,
            onFormatChanged: (f) => setState(() => _format = f),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = Diary.normalize(selected);
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) => _focusedDay = focused,
            eventLoader: (day) {
              return dateSet.contains(Diary.dateKeyOf(day))
                  ? const ['']
                  : const [];
            },
            calendarStyle: CalendarStyle(
              markerSize: 6,
              markerDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonShowsNext: false,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _DiaryPreview(
              date: _selectedDay,
              diary: selectedDiary,
              onTap: () => _openEditor(_selectedDay),
            ),
          ),
        ],
      ),
    );
  }
}

/// 선택된 날짜의 일기 미리보기.
/// 일상과 감사 일기 두 섹션을 각각 독립적으로 스크롤할 수 있게 분할 표시.
class _DiaryPreview extends StatelessWidget {
  final DateTime date;
  final Diary? diary;
  final VoidCallback onTap;

  const _DiaryPreview({
    required this.date,
    required this.diary,
    required this.onTap,
  });

  List<String> _filter(List<String>? src) =>
      (src ?? const []).where((s) => s.trim().isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR');
    final primary = Theme.of(context).colorScheme.primary;
    final sentences = _filter(diary?.sentences);
    final gratitudes = _filter(diary?.gratitudes);
    final bothEmpty = sentences.isEmpty && gratitudes.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상단 날짜 헤더 (탭하면 편집)
          Material(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        df.format(date),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 18, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (bothEmpty)
            Expanded(
              child: Center(
                child: Text(
                  '아직 작성된 일기가 없어요.\n탭해서 작성해 보세요.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
            )
          else ...[
            // 두 섹션이 모두 있으면 50:50 으로 나눠 각각 독립 스크롤.
            // 한 쪽만 있으면 그 섹션이 전체 공간을 차지.
            if (sentences.isNotEmpty)
              Expanded(
                child: ScrollToTop(
                  child: _Section(
                    title: '일상',
                    icon: Icons.format_list_bulleted,
                    color: primary,
                    items: sentences,
                  ),
                ),
              ),
            if (sentences.isNotEmpty && gratitudes.isNotEmpty)
              const SizedBox(height: 12),
            if (gratitudes.isNotEmpty)
              Expanded(
                child: ScrollToTop(
                  child: _Section(
                    title: '감사 일기',
                    icon: Icons.favorite,
                    color: Colors.pink.shade400,
                    items: gratitudes,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${items.length}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          // 각 섹션 독립 스크롤 — RefreshIndicator 로 당겨서 새로고침도 가능.
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => SyncManager.instance.pullOnLogin(),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                itemCount: items.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${items[i]}',
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

