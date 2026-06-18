import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/services/sync_manager.dart';
import '../models/news_article.dart';

/// 스크랩(북마크)한 뉴스 기사 로컬 저장. 독서 모듈의 BookStorageService와 동일 패턴.
class NewsStorageService {
  static const _key = 'news_bookmarks_v1';

  Future<List<NewsArticle>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const [];
    return list.map(NewsArticle.fromJsonString).toList();
  }

  Future<void> saveAll(List<NewsArticle> articles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      articles.map((e) => e.toJsonString()).toList(),
    );
    await SyncManager.instance.flushNow();
  }
}
