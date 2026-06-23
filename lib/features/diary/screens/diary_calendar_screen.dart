import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../auth/services/sync_manager.dart';
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
  // 일상/감사 두 섹션 각각의 ScrollController.
  final ScrollController _sentencesCtrl = ScrollController();
  final ScrollController _gratitudesCtrl = ScrollController();

  @override
  void dispose() {
    _sentencesCtrl.dispose();
    _gratitudesCtrl.dispose();
    super.dispose();
  }

  bool _anyScrolledDown() {
    bool offset(ScrollController c) =>
        c.hasClients && c.offset > 200;
    return offset(_sentencesCtrl) || offset(_gratitudesCtrl);
  }

  Future<void> _scrollBothToTop() async {
    for (final c in [_sentencesCtrl, _gratitudesCtrl]) {
      if (c.hasClients) {
        c.animateTo(0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic);
      }
    }
  }

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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _DiaryTopFab(
            sentencesCtrl: _sentencesCtrl,
            gratitudesCtrl: _gratitudesCtrl,
            onPressed: _scrollBothToTop,
            isVisible: _anyScrolledDown,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'diaryEdit',
            onPressed: () => _openEditor(_selectedDay),
            icon: Icon(selectedDiary == null ? Icons.edit : Icons.edit_note),
            label: Text(selectedDiary == null ? '일기 쓰기' : '일기 수정'),
          ),
        ],
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
              sentencesCtrl: _sentencesCtrl,
              gratitudesCtrl: _gratitudesCtrl,
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
  final ScrollController? sentencesCtrl;
  final ScrollController? gratitudesCtrl;

  const _DiaryPreview({
    required this.date,
    required this.diary,
    required this.onTap,
    this.sentencesCtrl,
    this.gratitudesCtrl,
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
                child: _Section(
                  title: '일상',
                  icon: Icons.format_list_bulleted,
                  color: primary,
                  items: sentences,
                  controller: sentencesCtrl,
                ),
              ),
            if (sentences.isNotEmpty && gratitudes.isNotEmpty)
              const SizedBox(height: 12),
            if (gratitudes.isNotEmpty)
              Expanded(
                child: _Section(
                  title: '감사 일기',
                  icon: Icons.favorite,
                  color: Colors.pink.shade400,
                  items: gratitudes,
                  controller: gratitudesCtrl,
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
  final ScrollController? controller;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    this.controller,
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
                controller: controller,
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

/// 일기 캘린더 전용 "맨 위로" FAB — 두 섹션 컨트롤러를 모두 감시,
/// 어느 한 쪽이라도 스크롤 내려가 있으면 노출.
class _DiaryTopFab extends StatefulWidget {
  final ScrollController sentencesCtrl;
  final ScrollController gratitudesCtrl;
  final VoidCallback onPressed;
  final bool Function() isVisible;

  const _DiaryTopFab({
    required this.sentencesCtrl,
    required this.gratitudesCtrl,
    required this.onPressed,
    required this.isVisible,
  });

  @override
  State<_DiaryTopFab> createState() => _DiaryTopFabState();
}

class _DiaryTopFabState extends State<_DiaryTopFab> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    widget.sentencesCtrl.addListener(_onChange);
    widget.gratitudesCtrl.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.sentencesCtrl.removeListener(_onChange);
    widget.gratitudesCtrl.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final next = widget.isVisible();
    if (next != _show) setState(() => _show = next);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_show,
      child: AnimatedOpacity(
        opacity: _show ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 180),
        child: FloatingActionButton.small(
          heroTag: 'diaryTop',
          tooltip: '맨 위로',
          onPressed: widget.onPressed,
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).colorScheme.primary,
          elevation: 3,
          shape: const CircleBorder(),
          child: const Icon(Icons.arrow_upward),
        ),
      ),
    );
  }
}
