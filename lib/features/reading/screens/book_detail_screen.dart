import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../providers/book_providers.dart';
import '../services/book_toc_service.dart';
import '../widgets/book_cover.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  final String bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  bool _fetchingToc = false;
  bool _autoFetchAttempted = false;

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider).value ?? const <Book>[];
    final book = books.where((b) => b.id == widget.bookId).firstOrNull;

    if (book == null) {
      return const Scaffold(body: Center(child: Text('책을 찾을 수 없어요')));
    }

    // 처음 열었을 때 목차가 비어있고 ISBN이 있으면 1회 자동 시도
    if (!_autoFetchAttempted && book.toc.isEmpty && book.isbn.isNotEmpty) {
      _autoFetchAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchToc(book, showErrorSnack: false);
      });
    }

    final isReading = book.status == BookStatus.reading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('책 상세'),
        actions: [
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(book.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BookHeader(book: book),
          if (book.description.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('소개', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(book.description),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Text('목차', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                icon: _fetchingToc
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_outlined, size: 18),
                label: const Text('자동 가져오기'),
                onPressed: _fetchingToc ? null : () => _fetchToc(book),
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('편집'),
                onPressed: () => _editToc(book),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (book.toc.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '아직 목차가 없어요. "자동 가져오기"로 알라딘에서 불러오거나 "편집"으로 직접 입력하세요.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            ...List.generate(book.toc.length, (i) {
              final item = book.toc[i];
              return CheckboxListTile(
                value: item.isRead,
                onChanged: (_) => ref
                    .read(booksProvider.notifier)
                    .toggleTocItem(book.id, i),
                title: Text(
                  item.title,
                  style: TextStyle(
                    decoration:
                        item.isRead ? TextDecoration.lineThrough : null,
                    color: item.isRead ? Colors.grey : null,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
          const SizedBox(height: 32),
          if (isReading)
            FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('다 읽었어요'),
              onPressed: () async {
                await ref.read(booksProvider.notifier).markFinished(book.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('완독한 책에 저장했어요 🎉')),
                  );
                }
              },
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('다시 읽는 중으로 변경'),
              onPressed: () =>
                  ref.read(booksProvider.notifier).markReading(book.id),
            ),
        ],
      ),
    );
  }

  Future<void> _fetchToc(Book book, {bool showErrorSnack = true}) async {
    setState(() => _fetchingToc = true);
    try {
      final svc = ref.read(bookTocServiceProvider);
      final titles = await svc.fetchByIsbn(book.isbn);
      final existingMap = {for (final e in book.toc) e.title: e.isRead};
      final newToc = titles
          .map((t) => TocItem(title: t, isRead: existingMap[t] ?? false))
          .toList();
      await ref.read(booksProvider.notifier).setToc(book.id, newToc);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('알라딘에서 ${newToc.length}개 챕터를 가져왔어요')),
        );
      }
    } on TocServiceUnavailable catch (e) {
      if (showErrorSnack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (showErrorSnack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('자동 가져오기 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingToc = false);
    }
  }

  Future<void> _editToc(Book book) async {
    final controller = TextEditingController(
      text: book.toc.map((e) => e.title).join('\n'),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('목차 편집'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            maxLines: 12,
            minLines: 6,
            decoration: const InputDecoration(
              hintText: '한 줄에 하나씩 챕터를 입력하세요\n예)\n1장. 시작\n2장. 핵심 원리\n...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final existingMap = {for (final e in book.toc) e.title: e.isRead};
    final newToc = result
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => TocItem(title: s, isRead: existingMap[s] ?? false))
        .toList();
    await ref.read(booksProvider.notifier).setToc(widget.bookId, newToc);
  }

  Future<void> _confirmDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('정말 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(booksProvider.notifier).remove(id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}

class _BookHeader extends StatelessWidget {
  final Book book;
  const _BookHeader({required this.book});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookCover(url: book.thumbnail, width: 96, height: 140),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(book.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(book.authors.join(', '),
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              Text(book.publisher,
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: book.progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
              ),
              const SizedBox(height: 4),
              Text(
                '진행도 ${(book.progress * 100).round()}%'
                '${book.toc.isEmpty ? "" : " (${book.toc.where((e) => e.isRead).length}/${book.toc.length})"}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
