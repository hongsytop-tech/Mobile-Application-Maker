import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/book_providers.dart';
import '../services/book_search_service.dart';
import '../widgets/book_cover.dart';
import 'book_detail_screen.dart';

class BookPreviewScreen extends ConsumerStatefulWidget {
  final BookSearchResult result;
  const BookPreviewScreen({super.key, required this.result});

  @override
  ConsumerState<BookPreviewScreen> createState() => _BookPreviewScreenState();
}

class _BookPreviewScreenState extends ConsumerState<BookPreviewScreen> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Scaffold(
      appBar: AppBar(title: const Text('책 정보')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(url: r.thumbnail, width: 110, height: 160),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.authors.join(', '),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.publisher,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    if (r.isbn.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'ISBN ${r.isbn}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (r.contents.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('소개', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(r.contents),
          ],
          const SizedBox(height: 32),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: _adding
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add),
            label: const Text('내 책장에 추가'),
            onPressed: _adding ? null : _add,
          ),
        ),
      ),
    );
  }

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      final book =
          await ref.read(booksProvider.notifier).addFromSearch(widget.result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${book.title}"을(를) 책장에 추가했어요')),
      );
      Navigator.of(context).pop(); // 미리보기 닫기
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookDetailScreen(bookId: book.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _adding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('추가 실패: $e')),
      );
    }
  }
}
