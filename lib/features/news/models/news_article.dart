import 'dart:convert';

/// 크롤링된 뉴스 기사 1건.
///
/// 소스(네이버/RSS/구글뉴스 등)에 상관없이 프록시가 이 형태로 정규화해서 내려준다.
class NewsArticle {
  final String id; // link 기반 안정적 식별자
  final String title;
  final String summary;
  final String link;
  final String source; // 언론사/피드 이름
  final DateTime? publishedAt;
  final String? imageUrl;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.link,
    required this.source,
    this.publishedAt,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'link': link,
        'source': source,
        'publishedAt': publishedAt?.toIso8601String(),
        'imageUrl': imageUrl,
      };

  factory NewsArticle.fromJson(Map<String, dynamic> j) => NewsArticle(
        // 프록시가 id를 안 주면 link를 식별자로 사용
        id: (j['id'] as String?)?.isNotEmpty == true
            ? j['id'] as String
            : (j['link'] as String? ?? ''),
        title: j['title'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        link: j['link'] as String? ?? '',
        source: j['source'] as String? ?? '',
        publishedAt: j['publishedAt'] == null
            ? null
            : DateTime.tryParse(j['publishedAt'] as String),
        imageUrl: j['imageUrl'] as String?,
      );

  String toJsonString() => jsonEncode(toJson());
  factory NewsArticle.fromJsonString(String s) =>
      NewsArticle.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
