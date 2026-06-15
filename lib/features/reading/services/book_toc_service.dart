import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TocServiceUnavailable implements Exception {
  final String message;
  const TocServiceUnavailable(this.message);
  @override
  String toString() => message;
}

class TocResult {
  final String? source; // 'aladin' | 'kyobo' | null
  final List<String> toc;
  final int? priceStandard;
  final int? priceSales;
  final String? link;

  const TocResult({
    required this.source,
    required this.toc,
    this.priceStandard,
    this.priceSales,
    this.link,
  });

  factory TocResult.fromJson(Map<String, dynamic> j) => TocResult(
        source: j['source'] as String?,
        toc: (j['toc'] as List? ?? []).cast<String>(),
        priceStandard: j['priceStandard'] as int?,
        priceSales: j['priceSales'] as int?,
        link: j['link'] as String?,
      );
}

/// 책 목차 자동 조회 — Supabase Edge Function (book-toc) 프록시를 호출.
///
/// 프록시 내부 흐름: 알라딘 → 교보문고 (둘 다 실패 시 빈 결과)
class BookTocService {
  String get _proxyUrl {
    final url = dotenv.maybeGet('BOOK_TOC_PROXY_URL') ?? '';
    if (url.isEmpty || url == 'your_supabase_function_url_here') {
      throw const TocServiceUnavailable(
        'TOC 프록시 URL이 설정되지 않았습니다. .env의 BOOK_TOC_PROXY_URL을 확인하세요.',
      );
    }
    return url;
  }

  Future<TocResult> fetch({String? isbn, String? title}) async {
    final params = <String, String>{};
    if (isbn != null && isbn.isNotEmpty) params['isbn'] = isbn;
    if (title != null && title.isNotEmpty) params['title'] = title;
    if (params.isEmpty) {
      throw const TocServiceUnavailable('ISBN 또는 제목이 필요합니다.');
    }

    final uri = Uri.parse(_proxyUrl).replace(queryParameters: params);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('프록시 오류 (${res.statusCode})');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (body['error'] != null) {
      throw TocServiceUnavailable('프록시: ${body['error']}');
    }
    final result = TocResult.fromJson(body);
    if (result.toc.isEmpty) {
      throw const TocServiceUnavailable(
        '알라딘·교보문고 어디에서도 목차를 찾지 못했어요.',
      );
    }
    return result;
  }

  /// 기존 호출부 호환용 — 챕터 제목 리스트만 반환
  Future<List<String>> fetchByIsbn(String isbn) async {
    final r = await fetch(isbn: isbn);
    return r.toc;
  }
}
