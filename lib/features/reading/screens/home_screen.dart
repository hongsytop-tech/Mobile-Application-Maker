import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/screens/profile_screen.dart';
import '../models/book.dart';
import '../providers/book_providers.dart';
import '../widgets/book_cover.dart';
import 'book_detail_screen.dart';
import 'search_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _openSearch({String? initialQuery}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(initialQuery: initialQuery),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncBooks = ref.watch(booksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 책장'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.bar_chart),
            label: const Text('독서 통계'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
          ),
          IconButton(
            tooltip: '내 정보 · 백업',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SearchBar(
                  leading: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.search),
                  ),
                  hintText: '책 제목 검색',
                  elevation: const WidgetStatePropertyAll(0),
                  onTap: () => _openSearch(),
                  onChanged: (q) {
                    if (q.isNotEmpty) _openSearch(initialQuery: q);
                  },
                ),
              ),
              TabBar(
                controller: _tab,
                isScrollable: false,
                labelPadding: EdgeInsets.zero,
                tabs: const [
                  Tab(text: '위시리스트'),
                  Tab(text: '읽고 있는 책'),
                  Tab(text: '내가 읽은 책'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: asyncBooks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (_) {
          final wishlist = ref.watch(wishlistBooksProvider);
          final reading = ref.watch(readingBooksProvider);
          final finished = ref.watch(finishedBooksProvider);
          return TabBarView(
            controller: _tab,
            children: [
              _BookList(
                books: wishlist,
                emptyText: '읽고 싶은 책을 위시리스트에 담아보세요.\n검색 후 "위시리스트 담기"를 누르면 됩니다.',
                showProgress: false,
              ),
              _BookList(
                books: reading,
                emptyText: '아직 읽고 있는 책이 없어요.\n위의 검색창에서 책을 찾아보세요.',
              ),
              _BookList(
                books: finished,
                emptyText: '완독한 책이 표시됩니다.',
                showProgress: false,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BookList extends ConsumerWidget {
  final List<Book> books;
  final String emptyText;
  final bool showProgress;

  const _BookList({
    required this.books,
    required this.emptyText,
    this.showProgress = true,
  });

  static final _won = NumberFormat('#,###');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        return Dismissible(
          key: ValueKey(b.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red.shade400,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text('"${b.title}"을(를) 삭제할까요?'),
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
          },
          onDismissed: (_) =>
              ref.read(booksProvider.notifier).remove(b.id),
          child: ListTile(
            leading: BookCover(url: b.thumbnail),
            title: Text(b.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
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
                else if (b.status == BookStatus.wishlist && b.priceSales != null)
                  Text('${_won.format(b.priceSales)}원',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600))
                else if (b.finishedAt != null)
                  Text('완독: ${df.format(b.finishedAt!)}',
                      style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) async {
                if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('"${b.title}"을(를) 삭제할까요?'),
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
                  if (ok == true) {
                    await ref.read(booksProvider.notifier).remove(b.id);
                  }
                } else if (v == 'edit') {
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookDetailScreen(bookId: b.id),
                      ),
                    );
                  }
                } else if (v == 'start') {
                  await ref.read(booksProvider.notifier).markReading(b.id);
                }
              },
              itemBuilder: (_) => [
                if (b.status == BookStatus.wishlist)
                  const PopupMenuItem(value: 'start', child: Text('읽기 시작')),
                const PopupMenuItem(value: 'edit', child: Text('편집/상세')),
                const PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BookDetailScreen(bookId: b.id),
              ),
            ),
          ),
        );
      },
    );
  }
}
