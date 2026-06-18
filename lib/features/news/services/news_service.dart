import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/news_article.dart';

class NewsServiceUnavailable implements Exception {
  final String message;
  const NewsServiceUnavailable(this.message);
  @override
  String toString() => message;
}

/// 뉴스 피드 정의. 어떤 소스를 쓸지는 추후 결정 — 여기 목록만 늘리면 된다.
/// `key` 는 프록시에 전달되는 식별자이고, `label` 은 UI 노출용.
class NewsFeed {
  final String key;
  final String label;
  const NewsFeed(this.key, this.label);
}

/// TODO(news): 실제 소스 확정 후 키/라벨 정리.
/// 현재는 프록시(news-crawl Edge Function)가 RSS 기반으로 정규화한다고 가정.
const kNewsFeeds = <NewsFeed>[
  NewsFeed('top', '주요뉴스'),
];

/// 뉴스 크롤링 — Supabase Edge Function 프록시(news-crawl) 호출.
///
/// 브라우저(웹)에서는 CORS로 외부 사이트를 직접 못 긁으므로,
/// 독서 모듈(book-toc)과 동일하게 서버 프록시를 거친다.
class NewsService {
  String get _proxyUrl {
    final url = dotenv.maybeGet('NEWS_CRAWL_PROXY_URL') ?? '';
    if (url.isEmpty || url == 'your_supabase_function_url_here') {
      throw const NewsServiceUnavailable(
        '뉴스 프록시 URL이 설정되지 않았습니다. .env의 NEWS_CRAWL_PROXY_URL을 확인하세요.',
      );
    }
    return url;
  }

  /// [feed] 또는 [query] 중 하나로 기사 목록을 가져온다.
  Future<List<NewsArticle>> fetch({
    String feed = 'top',
    String? query,
    bool forceRefresh = false,
  }) async {
    final params = <String, String>{'feed': feed};
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (forceRefresh) params['nocache'] = '1';

    final uri = Uri.parse(_proxyUrl).replace(queryParameters: params);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw NewsServiceUnavailable('프록시 오류 (${res.statusCode})');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (body['error'] != null) {
      throw NewsServiceUnavailable('프록시: ${body['error']}');
    }

    final items = (body['articles'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(NewsArticle.fromJson)
        .where((a) => a.link.isNotEmpty)
        .toList();
    return items;
  }
}
