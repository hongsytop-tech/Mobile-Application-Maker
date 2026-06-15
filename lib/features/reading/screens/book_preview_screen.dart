import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/book.dart';
import '../providers/book_providers.dart';
import '../services/book_search_service.dart';
import '../services/book_toc_service.dart';
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
  bool _fetchingMeta = false;
  BookMetadata? _meta;

  static final _won = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchMeta());
  }

  Future<void> _fetchMeta() async {
    if (widget.result.isbn.isEmpty && widget.result.title.isEmpty) return;
    setState(() => _fetchingMeta = true);
    try {
      final svc = ref.read(bookTocServiceProvider);
      final m = await svc.fetch(
        isbn: widget.result.isbn,
        title: widget.result.title,
      );
      if (mounted) setState(() => _meta = m);
    } catch (_) {
      // 가격 정보 가져오기 실패는 조용히 무시 (책 추가 자체는 가능)
    } finally {
      if (mounted) setState(() => _fetchingMeta = false);
    }
  }

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
                          color: Colors.grey, fontSize: 12),
                    ),
                    if (r.isbn.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'ISBN ${r.isbn}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MetaSection(
            meta: _meta,
            loading: _fetchingMeta,
            onRefresh: _fetchMeta,
          ),
          if (r.contents.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('소개', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(r.contents),
          ],
          if (_meta != null && _meta!.toc.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('목차 미리보기',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _meta!.toc
                    .take(15)
                    .map((t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('• $t'),
                        ))
                    .toList(),
              ),
            ),
            if (_meta!.toc.length > 15) ...[
              const SizedBox(height: 4),
              Text('… 외 ${_meta!.toc.length - 15}개',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ],
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _adding
              ? const Center(
                  heightFactor: 1.4,
                  child: CircularProgressIndicator(),
                )
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('위시리스트'),
                        onPressed: () => _add(BookStatus.wishlist),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.menu_book),
                        label: const Text('읽기 시작'),
                        onPressed: () => _add(BookStatus.reading),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _add(BookStatus status) async {
    setState(() => _adding = true);
    try {
      final notifier = ref.read(booksProvider.notifier);
      final book = await notifier.addFromSearch(widget.result, status: status);
      // 미리보기에서 이미 가져온 메타데이터를 즉시 반영
      if (_meta != null) {
        await notifier.applyMetadata(book.id, _meta!);
      }
      if (!mounted) return;
      final label = status == BookStatus.wishlist ? '위시리스트' : '책장';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${book.title}"을(를) $label에 담았어요')),
      );
      Navigator.of(context).pop();
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

class _MetaSection extends StatelessWidget {
  final BookMetadata? meta;
  final bool loading;
  final VoidCallback onRefresh;

  const _MetaSection({
    required this.meta,
    required this.loading,
    required this.onRefresh,
  });

  static final _won = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    if (loading && meta == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('가격·구매 정보 가져오는 중…',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    if (meta == null) return const SizedBox.shrink();

    final m = meta!;
    final hasPrice = m.priceStandard != null || m.priceSales != null;
    if (!hasPrice && m.aladinLink == null && m.kyoboLink == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasPrice)
            Row(
              children: [
                if (m.priceSales != null) ...[
                  Text(
                    '${_won.format(m.priceSales)}원',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                ],
                if (m.priceStandard != null &&
                    m.priceStandard != m.priceSales)
                  Text(
                    '${_won.format(m.priceStandard)}원',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: '다시 불러오기',
                  onPressed: loading ? null : onRefresh,
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                ),
              ],
            ),
          if (m.aladinLink != null || m.kyoboLink != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (m.aladinLink != null)
                  FilledButton.icon(
                    onPressed: () => _open(m.aladinLink!),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('알라딘에서 보기'),
                  ),
                if (m.kyoboLink != null)
                  OutlinedButton.icon(
                    onPressed: () => _open(m.kyoboLink!),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('교보문고에서 보기'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
