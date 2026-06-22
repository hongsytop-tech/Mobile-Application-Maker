import 'package:flutter/material.dart';

import '../models/recommended_book.dart';

/// 오늘의 추천 책 상세 — 제목/저자/요약/목차.
class BookRecommendDetailScreen extends StatelessWidget {
  final RecommendedBook book;
  const BookRecommendDetailScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 추천 책')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_stories, color: primary, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(book.author,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('요약', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(book.summary,
              style: const TextStyle(fontSize: 14, height: 1.6)),
          const SizedBox(height: 24),
          Text('목차', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final t in book.toc)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Icon(Icons.chevron_right,
                        size: 16, color: primary),
                  ),
                  Expanded(
                    child: Text(t,
                        style: const TextStyle(fontSize: 14, height: 1.4)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'ℹ️ 추천 책은 매일 한 권씩 바뀝니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
