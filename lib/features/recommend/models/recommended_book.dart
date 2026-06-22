/// 추천 책 한 권 (큐레이션 데이터).
class RecommendedBook {
  final String title;
  final String author;
  final String summary;
  final List<String> toc;

  const RecommendedBook({
    required this.title,
    required this.author,
    required this.summary,
    required this.toc,
  });
}
