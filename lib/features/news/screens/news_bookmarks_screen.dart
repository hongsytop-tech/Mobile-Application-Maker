import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/news_article.dart';
import '../providers/news_providers.dart';
import '../widgets/news_card.dart';

/// 스크랩한 기사 목록.
class NewsBookmarksScreen extends ConsumerWidget {
  const NewsBookmarksScreen({super.key});

  Future<void> _open(NewsArticle a) async {
    final uri = Uri.tryParse(a.link);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('스크랩')),
      body: bookmarks.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '스크랩한 기사가 없어요.\n기사 오른쪽 북마크 아이콘을 눌러 저장하세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: bookmarks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final a = bookmarks[i];
                return Dismissible(
                  key: ValueKey(a.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red.shade400,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) =>
                      ref.read(bookmarksProvider.notifier).remove(a.id),
                  child: NewsCard(
                    article: a,
                    bookmarked: true,
                    onTap: () => _open(a),
                    onToggleBookmark: () =>
                        ref.read(bookmarksProvider.notifier).remove(a.id),
                  ),
                );
              },
            ),
    );
  }
}
