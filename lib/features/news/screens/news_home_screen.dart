import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/news_article.dart';
import '../providers/news_providers.dart';
import '../services/news_service.dart';
import '../widgets/news_card.dart';
import 'news_bookmarks_screen.dart';

/// 뉴스 탭 메인 — 피드별 기사 목록 + 당겨서 새로고침 + 스크랩.
class NewsHomeScreen extends ConsumerWidget {
  const NewsHomeScreen({super.key});

  Future<void> _open(BuildContext context, NewsArticle a) async {
    final uri = Uri.tryParse(a.link);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크를 열 수 없습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFeed = ref.watch(selectedFeedProvider);
    final asyncNews = ref.watch(newsFeedProvider);
    final bookmarks = ref.watch(bookmarksProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('뉴스'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: '스크랩',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NewsBookmarksScreen()),
            ),
          ),
        ],
        bottom: kNewsFeeds.length <= 1
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final f in kNewsFeeds)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(f.label),
                            selected: f.key == selectedFeed,
                            onSelected: (_) => ref
                                .read(selectedFeedProvider.notifier)
                                .state = f.key,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(newsFeedProvider.future),
        child: asyncNews.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    e is NewsServiceUnavailable
                        ? '$e'
                        : '뉴스를 불러오지 못했어요.\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
          data: (articles) {
            if (articles.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('표시할 뉴스가 없어요.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: articles.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final a = articles[i];
                final isMarked = bookmarks.any((b) => b.id == a.id);
                return NewsCard(
                  article: a,
                  bookmarked: isMarked,
                  onTap: () => _open(context, a),
                  onToggleBookmark: () =>
                      ref.read(bookmarksProvider.notifier).toggle(a),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
