import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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

class _DiaryPreview extends StatelessWidget {
  final DateTime date;
  final Diary? diary;
  final VoidCallback onTap;

  const _DiaryPreview({
    required this.date,
    required this.diary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR');

    return Material(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                df.format(date),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              if (diary == null || diary!.isEmpty)
                Text(
                  '아직 작성된 일기가 없어요.\n탭해서 작성해 보세요.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                )
              else if (diary!.mode == DiaryMode.freeform)
                Text(
                  diary!.freeText,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: diary!.sentences
                      .where((s) => s.trim().isNotEmpty)
                      .map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $s',
                                style: const TextStyle(
                                    fontSize: 14, height: 1.5)),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
