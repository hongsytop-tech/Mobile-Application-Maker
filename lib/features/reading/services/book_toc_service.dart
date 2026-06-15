import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TocServiceUnavailable implements Exception {
  final String message;
  const TocServiceUnavailable(this.message);
  @override
  String toString() => message;
}

/// 책의 목차를 외부 API에서 가져온다.
///
/// 현재 구현: 알라딘 ItemLookUp API (ISBN 기반)
/// 추후 폴백 체인: 알라딘 → 교보문고 프록시(Edge Function) → AI 추정
class BookTocService {
  static const _aladinEndpoint =
      'https://www.aladin.co.kr/ttb/api/ItemLookUp.aspx';

  String get _aladinKey {
    final k = dotenv.maybeGet('ALADIN_TTB_KEY') ?? '';
    if (k.isEmpty || k == 'your_aladin_ttb_key_here') {
      throw const TocServiceUnavailable(
        '알라딘 TTB 키가 설정되지 않았습니다. .env에 ALADIN_TTB_KEY를 추가하세요.',
      );
    }
    return k;
  }

  Future<List<String>> fetchByIsbn(String isbn) async {
    final clean = isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    if (clean.isEmpty) {
      throw const TocServiceUnavailable('ISBN 정보가 없어 자동 조회할 수 없어요.');
    }

    final uri = Uri.parse(_aladinEndpoint).replace(queryParameters: {
      'ttbkey': _aladinKey,
      'itemIdType': clean.length == 13 ? 'ISBN13' : 'ISBN',
      'ItemId': clean,
      'output': 'js',
      'Version': '20131101',
      'OptResult': 'Toc',
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('알라딘 API 오류 (${res.statusCode})');
    }

    final body = _decodeMaybeJsonp(utf8.decode(res.bodyBytes));
    if (body == null) {
      throw const TocServiceUnavailable('응답을 해석할 수 없어요.');
    }
    if (body['errorCode'] != null) {
      throw TocServiceUnavailable(
        '알라딘 오류: ${body['errorMessage'] ?? body['errorCode']}',
      );
    }

    final items = body['item'] as List?;
    if (items == null || items.isEmpty) {
      throw const TocServiceUnavailable('알라딘에서 해당 도서를 찾지 못했어요.');
    }

    final sub = (items.first as Map<String, dynamic>)['subInfo']
        as Map<String, dynamic>?;
    final tocHtml = sub?['toc'] as String? ?? '';
    final parsed = _parseTocHtml(tocHtml);
    if (parsed.isEmpty) {
      throw const TocServiceUnavailable('알라딘에 목차 정보가 없어요.');
    }
    return parsed;
  }

  Map<String, dynamic>? _decodeMaybeJsonp(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.endsWith(';')) s = s.substring(0, s.length - 1);
    // 일부 응답이 trailing comma를 포함하는 경우 보정
    s = s.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  List<String> _parseTocHtml(String html) {
    if (html.isEmpty) return const [];
    final withNewlines = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n');
    final stripped = withNewlines.replaceAll(RegExp(r'<[^>]+>'), '');
    final decoded = _decodeHtmlEntities(stripped);
    return decoded
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String _decodeHtmlEntities(String s) {
    return s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}
