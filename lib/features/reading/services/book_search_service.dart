import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class BookSearchResult {
  final String title;
  final List<String> authors;
  final String publisher;
  final String thumbnail;
  final String contents;
  final String isbn;

  const BookSearchResult({
    required this.title,
    required this.authors,
    required this.publisher,
    required this.thumbnail,
    required this.contents,
    required this.isbn,
  });
}

class BookSearchService {
  static const _endpoint = 'https://dapi.kakao.com/v3/search/book';

  String get _apiKey {
    final key = dotenv.maybeGet('KAKAO_REST_API_KEY') ?? '';
    if (key.isEmpty || key == 'your_kakao_rest_api_key_here') {
      throw Exception(
        '카카오 REST API 키가 설정되지 않았습니다. .env 파일을 확인하세요.',
      );
    }
    return key;
  }

  Future<List<BookSearchResult>> search(String query, {int size = 10}) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'query': query,
      'size': '$size',
      'sort': 'accuracy',
    });

    final res = await http.get(
      uri,
      headers: {'Authorization': 'KakaoAK $_apiKey'},
    );

    if (res.statusCode != 200) {
      throw Exception('검색 실패: ${res.statusCode} ${res.body}');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final docs = (body['documents'] as List).cast<Map<String, dynamic>>();
    return docs.map((d) {
      final isbnRaw = (d['isbn'] as String? ?? '').split(' ');
      return BookSearchResult(
        title: d['title'] as String? ?? '',
        authors: (d['authors'] as List? ?? []).cast<String>(),
        publisher: d['publisher'] as String? ?? '',
        thumbnail: d['thumbnail'] as String? ?? '',
        contents: d['contents'] as String? ?? '',
        isbn: isbnRaw.isNotEmpty ? isbnRaw.last : '',
      );
    }).toList();
  }
}
