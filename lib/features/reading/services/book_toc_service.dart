import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TocServiceUnavailable implements Exception {
  final String message;
  const TocServiceUnavailable(this.message);
  @override
  String toString() => message;
}

class BookMetadata {
  final List<String> toc;
  final String? tocSource; // 'aladin' | null
  final int? priceStandard;
  final int? priceSales;
  final String? aladinLink;
  final String? kyoboLink;

  const BookMetadata({
    required this.toc,
    this.tocSource,
    this.priceStandard,
    this.priceSales,
    this.aladinLink,
    this.kyoboLink,
  });

  bool get hasAnything =>
      toc.isNotEmpty ||
      priceStandard != null ||
      priceSales != null ||
      aladinLink != null ||
      kyoboLink != null;

  factory BookMetadata.fromJson(Map<String, dynamic> j) => BookMetadata(
        toc: (j['toc'] as List? ?? []).cast<String>(),
        tocSource: j['tocSource'] as String?,
        priceStandard: j['priceStandard'] as int?,
        priceSales: j['priceSales'] as int?,
        aladinLink: j['aladinLink'] as String?,
        kyoboLink: j['kyoboLink'] as String?,
      );
}

/// 책 메타데이터 조회 — Supabase Edge Function 프록시 호출.
/// 알라딘(가격·링크·TOC) + 교보문고(정보 링크)
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

  Future<BookMetadata> fetch({String? isbn, String? title}) async {
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
    return BookMetadata.fromJson(body);
  }
}
