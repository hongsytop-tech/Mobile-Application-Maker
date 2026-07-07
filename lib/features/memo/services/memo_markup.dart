import 'package:flutter/material.dart';

/// 메모 서식(진하게/기울임/밑줄)을 마크다운식 마커로 표현한다.
///   **진하게**   *기울임*   __밑줄__
/// 저장은 평문 문자열 그대로라 기존 메모와 호환된다.

enum MemoFmt { plain, bold, italic, underline }

class MemoSeg {
  final String text;
  final MemoFmt fmt;

  /// 마커(**, *, __) 자체인지 (편집 화면에서 흐리게 표시, 미리보기에선 숨김)
  final bool marker;
  const MemoSeg(this.text, this.fmt, this.marker);
}

// 굵게(**..**)를 기울임(*..*)보다 먼저 시도. 마커 안에 같은 기호·줄바꿈은 불허.
final RegExp _re = RegExp(
  r'\*\*([^*\n]+?)\*\*|__([^_\n]+?)__|\*([^*\n]+?)\*',
);

/// 텍스트를 서식 세그먼트로 분해.
List<MemoSeg> tokenizeMemo(String s) {
  final segs = <MemoSeg>[];
  var last = 0;
  for (final m in _re.allMatches(s)) {
    if (m.start > last) {
      segs.add(MemoSeg(s.substring(last, m.start), MemoFmt.plain, false));
    }
    late MemoFmt fmt;
    late String open;
    late String content;
    if (m.group(1) != null) {
      fmt = MemoFmt.bold;
      open = '**';
      content = m.group(1)!;
    } else if (m.group(2) != null) {
      fmt = MemoFmt.underline;
      open = '__';
      content = m.group(2)!;
    } else {
      fmt = MemoFmt.italic;
      open = '*';
      content = m.group(3)!;
    }
    segs.add(MemoSeg(open, fmt, true));
    segs.add(MemoSeg(content, fmt, false));
    segs.add(MemoSeg(open, fmt, true));
    last = m.end;
  }
  if (last < s.length) {
    segs.add(MemoSeg(s.substring(last), MemoFmt.plain, false));
  }
  return segs;
}

TextStyle styleFor(MemoFmt f, TextStyle base) {
  switch (f) {
    case MemoFmt.bold:
      return base.merge(const TextStyle(fontWeight: FontWeight.bold));
    case MemoFmt.italic:
      return base.merge(const TextStyle(fontStyle: FontStyle.italic));
    case MemoFmt.underline:
      return base.merge(const TextStyle(decoration: TextDecoration.underline));
    case MemoFmt.plain:
      return base;
  }
}

/// 표시용(미리보기/읽기) — 마커는 숨기고 서식만 적용.
List<InlineSpan> memoSpans(String text, TextStyle base) => [
      for (final seg in tokenizeMemo(text))
        if (!seg.marker) TextSpan(text: seg.text, style: styleFor(seg.fmt, base)),
    ];

/// 선택 영역에 마커를 토글로 적용한다. (선택 없으면 마커 쌍 삽입 후 커서를 사이에)
TextEditingValue applyMemoMarker(TextEditingValue v, String mark) {
  final sel = v.selection;
  if (!sel.isValid) return v;
  final text = v.text;
  final start = sel.start;
  final end = sel.end;
  final selected = text.substring(start, end);
  final before = text.substring(0, start);
  final after = text.substring(end);

  // 이미 바깥이 마커로 감싸져 있으면 해제
  if (before.endsWith(mark) && after.startsWith(mark)) {
    final newText = before.substring(0, before.length - mark.length) +
        selected +
        after.substring(mark.length);
    final ns = start - mark.length;
    return TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: ns, extentOffset: ns + selected.length),
    );
  }
  // 선택 자체가 마커를 포함하면 벗기기
  if (selected.length >= mark.length * 2 &&
      selected.startsWith(mark) &&
      selected.endsWith(mark)) {
    final inner = selected.substring(mark.length, selected.length - mark.length);
    final newText = before + inner + after;
    return TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: start, extentOffset: start + inner.length),
    );
  }
  // 감싸기
  final newText = '$before$mark$selected$mark$after';
  final ns = start + mark.length;
  return TextEditingValue(
    text: newText,
    selection: TextSelection(baseOffset: ns, extentOffset: ns + selected.length),
  );
}

/// 편집 화면용 컨트롤러 — 입력 중에도 서식을 실시간 렌더링(마커는 흐리게).
/// 한글 IME 조합 중에는 기본 렌더링을 사용해 입력을 방해하지 않는다.
class RichMemoEditingController extends TextEditingController {
  RichMemoEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    // 조합(composing) 중이면 기본 동작 유지 (한글 입력 안정성)
    if (withComposing && value.composing.isValid && !value.composing.isCollapsed) {
      return super
          .buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final markerColor = base.color?.withOpacity(0.35) ??
        Colors.grey.withOpacity(0.5);
    return TextSpan(
      style: base,
      children: [
        for (final seg in tokenizeMemo(text))
          TextSpan(
            text: seg.text,
            style: seg.marker
                ? base.copyWith(color: markerColor)
                : styleFor(seg.fmt, base),
          ),
      ],
    );
  }
}
