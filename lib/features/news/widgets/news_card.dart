import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/news_article.dart';

/// 뉴스 목록의 한 행. 썸네일 + 제목 + 출처/시각 + 스크랩 토글.
class NewsCard extends StatelessWidget {
  final NewsArticle article;
  final bool bookmarked;
  final VoidCallback onTap;
  final VoidCallback onToggleBookmark;

  const NewsCard({
    super.key,
    required this.article,
    required this.bookmarked,
    required this.onTap,
    required this.onToggleBookmark,
  });

  static final _df = DateFormat('MM.dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (article.source.isNotEmpty) article.source,
      if (article.publishedAt != null) _df.format(article.publishedAt!),
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: article.imageUrl == null || article.imageUrl!.isEmpty
          ? null
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: article.imageUrl!,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox(
                  width: 72,
                  height: 72,
                  child: Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
      title: Text(
        article.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.summary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(article.summary,
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          bookmarked ? Icons.bookmark : Icons.bookmark_border,
          color: bookmarked ? Theme.of(context).colorScheme.primary : null,
        ),
        onPressed: onToggleBookmark,
      ),
      onTap: onTap,
    );
  }
}
