import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/book.dart';
import '../providers/book_providers.dart';
import '../widgets/book_cover.dart';
import 'book_detail_screen.dart';
import 'search_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncBooks = ref.watch(booksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 책장'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '읽고 있는 책'),
            Tab(text: '내가 읽은 책'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        ),
        icon: const Icon(Icons.search),
        label: const Text('책 검색'),
      ),
      body: asyncBooks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (_) {
          final reading = ref.watch(readingBooksProvider);
          final finished = ref.watch(finishedBooksProvider);
          return TabBarView(
            controller: _tab,
            children: [
              _BookList(books: reading, emptyText: '아직 읽고 있는 책이 없어요.\n오른쪽 아래에서 책을 검색해 보세요.'),
              _BookList(books: finished, emptyText: '완독한 책이 표시됩니다.', showProgress: false),
            ],
          );
        },
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  final List<Book> books;
  final String emptyText;
  final bool showProgress;

  const _BookList({
    required this.books,
    required this.emptyText,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    final df = DateFormat('yyyy.MM.dd');
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: books.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final b = books[i];
        return ListTile(
          leading: BookCover(url: b.thumbnail),
          title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.authors.join(', '),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              if (showProgress)
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: b.progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(b.progress * 100).round()}%'),
                  ],
                )
              else if (b.finishedAt != null)
                Text('완독: ${df.format(b.finishedAt!)}',
                    style: const TextStyle(fontSize: 12)),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: b.id)),
          ),
        );
      },
    );
  }
}
