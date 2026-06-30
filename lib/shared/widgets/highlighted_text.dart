import 'package:flutter/material.dart';

/// 텍스트에서 [query] 와 일치하는 부분을 강조(하이라이트)해 보여주는 위젯.
/// 대소문자 구분 없이 모든 일치 구간을 노란 배경 + 굵게 표시한다.
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  const HighlightedText(
    this.text, {
    super.key,
    required this.query,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final q = query.trim();
    if (q.isEmpty) {
      return Text(text, style: base, maxLines: maxLines, overflow: overflow);
    }

    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final lowerQ = q.toLowerCase();
    int start = 0;
    while (true) {
      final idx = lower.indexOf(lowerQ, start);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + q.length),
        style: const TextStyle(
          backgroundColor: Color(0xFFFFF176), // amber 200
          fontWeight: FontWeight.bold,
        ),
      ));
      start = idx + q.length;
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// [text] 안에서 [query] 첫 일치 지점 주변을 잘라낸 스니펫을 반환.
/// 일치가 길 때 앞뒤 [pad] 글자만 남기고 "…" 로 줄인다. 일치 없으면 앞부분.
String snippetAround(String text, String query, {int pad = 30}) {
  final flat = text.replaceAll('\n', ' ').trim();
  final q = query.trim();
  if (q.isEmpty) return flat;
  final idx = flat.toLowerCase().indexOf(q.toLowerCase());
  if (idx < 0) {
    return flat.length <= pad * 2 ? flat : '${flat.substring(0, pad * 2)}…';
  }
  var startCut = idx - pad;
  var endCut = idx + q.length + pad;
  final prefix = startCut > 0 ? '…' : '';
  final suffix = endCut < flat.length ? '…' : '';
  startCut = startCut.clamp(0, flat.length);
  endCut = endCut.clamp(0, flat.length);
  return '$prefix${flat.substring(startCut, endCut)}$suffix';
}
