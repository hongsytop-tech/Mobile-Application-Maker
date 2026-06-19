import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/book.dart';
import '../services/book_search_service.dart';
import '../services/book_storage_service.dart';
import '../services/book_toc_service.dart' show BookTocService, BookMetadata;

final bookSearchServiceProvider = Provider((_) => BookSearchService());
final bookStorageServiceProvider = Provider((_) => BookStorageService());
final bookTocServiceProvider = Provider((_) => BookTocService());

final booksProvider =
    AsyncNotifierProvider<BooksNotifier, List<Book>>(BooksNotifier.new);

class BooksNotifier extends AsyncNotifier<List<Book>> {
  static const _uuid = Uuid();

  @override
  Future<List<Book>> build() async {
    final storage = ref.read(bookStorageServiceProvider);
    return storage.loadAll();
  }

  Future<void> _persist(List<Book> books) async {
    state = AsyncData(books);
    await ref.read(bookStorageServiceProvider).saveAll(books);
  }

  Future<Book> addFromSearch(
    BookSearchResult r, {
    BookStatus status = BookStatus.reading,
  }) async {
    final existing = state.value ?? const <Book>[];
    if (r.isbn.isNotEmpty &&
        existing.any((b) => b.isbn == r.isbn)) {
      return existing.firstWhere((b) => b.isbn == r.isbn);
    }
    final book = Book(
      id: _uuid.v4(),
      title: r.title,
      authors: r.authors,
      publisher: r.publisher,
      thumbnail: r.thumbnail,
      description: r.contents,
      isbn: r.isbn,
      toc: const [],
      status: status,
      addedAt: DateTime.now(),
    );
    await _persist([...existing, book]);
    return book;
  }

  Future<void> updateBook(Book updated) async {
    final list = (state.value ?? const <Book>[])
        .map((b) => b.id == updated.id ? updated : b)
        .toList();
    await _persist(list);
  }

  Future<void> setToc(String id, List<TocItem> toc) async {
    final list = state.value ?? const <Book>[];
    final book = list.firstWhere((b) => b.id == id);
    await updateBook(book.copyWith(toc: toc));
  }

  Future<void> setNotes(String id, String notes) async {
    final list = state.value ?? const <Book>[];
    final book = list.firstWhere((b) => b.id == id);
    await updateBook(book.copyWith(notes: notes));
  }

  Future<void> applyMetadata(String id, BookMetadata m) async {
    final list = state.value ?? const <Book>[];
    final book = list.firstWhere((b) => b.id == id);
    final existingMap = {for (final e in book.toc) e.title: e.isRead};
    final newToc = m.toc.isNotEmpty
        ? m.toc
            .map((t) => TocItem(title: t, isRead: existingMap[t] ?? false))
            .toList()
        : book.toc;
    await updateBook(book.copyWith(
      toc: newToc,
      priceStandard: m.priceStandard,
      priceSales: m.priceSales,
      aladinLink: m.aladinLink,
      kyoboLink: m.kyoboLink,
    ));
  }

  Future<void> toggleTocItem(String id, int index) async {
    final list = state.value ?? const <Book>[];
    final book = list.firstWhere((b) => b.id == id);
    final newToc = [...book.toc];
    newToc[index] = newToc[index].copyWith(isRead: !newToc[index].isRead);
    await updateBook(book.copyWith(toc: newToc));
  }

  Future<void> markFinished(String id) async {
    final list = state.value ?? const <Book>[];
    final book = list.firstWhere((b) => b.id == id);
    final completedToc =
        book.toc.map((e) => e.copyWith(isRead: true)).toList();
    await updateBook(book.copyWith(
      toc: completedToc,
      status: BookStatus.finished,
      finishedAt: DateTime.now(),
    ));
  }

  Future<void> markReading(String id) async {
    final list = state.value ?? const <Book>[];
    final book = list.firstWhere((b) => b.id == id);
    await updateBook(book.copyWith(status: BookStatus.reading));
  }

  Future<void> remove(String id) async {
    final list = (state.value ?? const <Book>[])
        .where((b) => b.id != id)
        .toList();
    await _persist(list);
  }
}

final wishlistBooksProvider = Provider<List<Book>>((ref) {
  return ref.watch(booksProvider).value
          ?.where((b) => b.status == BookStatus.wishlist)
          .toList() ??
      const [];
});

final readingBooksProvider = Provider<List<Book>>((ref) {
  return ref.watch(booksProvider).value
          ?.where((b) => b.status == BookStatus.reading)
          .toList() ??
      const [];
});

final finishedBooksProvider = Provider<List<Book>>((ref) {
  return ref.watch(booksProvider).value
          ?.where((b) => b.status == BookStatus.finished)
          .toList() ??
      const [];
});
