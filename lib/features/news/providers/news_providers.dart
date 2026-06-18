import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/news_article.dart';
import '../services/news_service.dart';
import '../services/news_storage_service.dart';

final newsServiceProvider = Provider((_) => NewsService());
final newsStorageServiceProvider = Provider((_) => NewsStorageService());

/// 현재 선택된 피드 키 (기본: 주요뉴스).
final selectedFeedProvider = StateProvider<String>((_) => kNewsFeeds.first.key);

/// 선택된 피드의 기사 목록. 피드가 바뀌면 자동 재조회.
final newsFeedProvider = FutureProvider<List<NewsArticle>>((ref) async {
  final feed = ref.watch(selectedFeedProvider);
  return ref.read(newsServiceProvider).fetch(feed: feed);
});

/// 스크랩(북마크)한 기사 목록.
final bookmarksProvider =
    AsyncNotifierProvider<BookmarksNotifier, List<NewsArticle>>(
        BookmarksNotifier.new);

class BookmarksNotifier extends AsyncNotifier<List<NewsArticle>> {
  @override
  Future<List<NewsArticle>> build() async {
    return ref.read(newsStorageServiceProvider).loadAll();
  }

  Future<void> _persist(List<NewsArticle> list) async {
    state = AsyncData(list);
    await ref.read(newsStorageServiceProvider).saveAll(list);
  }

  bool isBookmarked(String id) =>
      (state.value ?? const []).any((a) => a.id == id);

  Future<void> toggle(NewsArticle article) async {
    final list = state.value ?? const <NewsArticle>[];
    final exists = list.any((a) => a.id == article.id);
    await _persist(
      exists
          ? list.where((a) => a.id != article.id).toList()
          : [article, ...list],
    );
  }

  Future<void> remove(String id) async {
    final list = (state.value ?? const <NewsArticle>[])
        .where((a) => a.id != id)
        .toList();
    await _persist(list);
  }
}
