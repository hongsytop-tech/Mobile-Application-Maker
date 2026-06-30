import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/highlighted_text.dart';
import '../models/diary.dart';
import '../providers/diary_providers.dart';
import 'diary_edit_screen.dart';

/// 한 날짜의 일기에서 키워드와 일치한 줄들.
class _DiaryHit {
  final Diary diary;
  final List<_Line> lines;
  const _DiaryHit(this.diary, this.lines);
}

class _Line {
  final String section; // '일상' | '감사 일기'
  final String text;
  const _Line(this.section, this.text);
}

/// 일기 키워드 검색 — 일상·감사 일기 내용에서 키워드가 포함된 날짜와 줄을 보여준다.
class DiarySearchScreen extends ConsumerStatefulWidget {
  const DiarySearchScreen({super.key});

  @override
  ConsumerState<DiarySearchScreen> createState() => _DiarySearchScreenState();
}

class _DiarySearchScreenState extends ConsumerState<DiarySearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<_DiaryHit> _search(List<Diary> all, String q) {
    final lowerQ = q.toLowerCase();
    final hits = <_DiaryHit>[];
    for (final d in all) {
      final lines = <_Line>[];
      for (final s in d.sentences) {
        if (s.toLowerCase().contains(lowerQ)) lines.add(_Line('일상', s));
      }
      for (final g in d.gratitudes) {
        if (g.toLowerCase().contains(lowerQ)) lines.add(_Line('감사 일기', g));
      }
      // 옛 서술형(freeText) 데이터도 검색 대상에 포함
      if (d.freeText.toLowerCase().contains(lowerQ) && lines.isEmpty) {
        lines.add(_Line('일상', d.freeText.trim()));
      }
      if (lines.isNotEmpty) hits.add(_DiaryHit(d, lines));
    }
    hits.sort((a, b) => b.diary.date.compareTo(a.diary.date));
    return hits;
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(diariesProvider).value ?? const <Diary>[];
    final q = _query.trim();
    final results = q.isEmpty ? const <_DiaryHit>[] : _search(all, q);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '일기 검색 (일상·감사)',
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
              ? _hint('"$q" 가 포함된 일기가 없어요.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _DiaryResultCard(hit: results[i], query: q),
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

class _DiaryResultCard extends StatelessWidget {
  final _DiaryHit hit;
  final String query;
  const _DiaryResultCard({required this.hit, required this.query});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR');
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => DiaryEditScreen(date: hit.diary.date)),
        ),
        child: Container(
          decoration: BoxDecoration(
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
                  Text(df.format(hit.diary.date),
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: primary)),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      size: 18, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 8),
              ...hit.lines.take(6).map((l) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2, right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: l.section == '감사 일기'
                                ? Colors.pink.shade50
                                : primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l.section,
                            style: TextStyle(
                                fontSize: 10,
                                color: l.section == '감사 일기'
                                    ? Colors.pink.shade400
                                    : primary),
                          ),
                        ),
                        Expanded(
                          child: HighlightedText(
                            l.text,
                            query: query,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )),
              if (hit.lines.length > 6)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 2),
                  child: Text('…외 ${hit.lines.length - 6}건',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
