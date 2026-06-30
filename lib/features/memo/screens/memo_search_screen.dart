import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/highlighted_text.dart';
import '../models/memo.dart';
import '../providers/memo_providers.dart';
import 'memo_edit_screen.dart';

/// 메모 키워드 검색 — 제목·내용에 키워드가 포함된 메모를 찾아 보여준다.
class MemoSearchScreen extends ConsumerStatefulWidget {
  const MemoSearchScreen({super.key});

  @override
  ConsumerState<MemoSearchScreen> createState() => _MemoSearchScreenState();
}

class _MemoSearchScreenState extends ConsumerState<MemoSearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(memosProvider).value ?? const <Memo>[];
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? const <Memo>[]
        : (all.where((m) =>
            m.title.toLowerCase().contains(q) ||
            m.content.toLowerCase().contains(q)).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '메모 검색 (제목·내용)',
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
              ? _hint('"$_query" 가 포함된 메모가 없어요.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _MemoResultCard(memo: results[i], query: _query),
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

class _MemoResultCard extends StatelessWidget {
  final Memo memo;
  final String query;
  const _MemoResultCard({required this.memo, required this.query});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy.MM.dd HH:mm');
    final title = memo.title.trim().isEmpty ? '(제목 없음)' : memo.title;
    // 본문은 키워드 주변만 잘라 보여준다.
    final snippet = snippetAround(memo.content, query);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MemoEditScreen(memo: memo)),
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
              HighlightedText(
                title,
                query: query,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: memo.title.trim().isEmpty ? Colors.grey : null,
                ),
                maxLines: 1,
              ),
              if (snippet.isNotEmpty) ...[
                const SizedBox(height: 6),
                HighlightedText(
                  snippet,
                  query: query,
                  maxLines: 3,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(df.format(memo.updatedAt),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
