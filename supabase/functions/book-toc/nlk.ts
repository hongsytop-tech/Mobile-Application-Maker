export interface NlkResult {
  toc: string[];
  _debug?: {
    hasKey: boolean;
    found: boolean;
    rawTocLen?: number;
    fromUrl?: boolean;
  };
}

const ENDPOINT = 'https://www.nl.go.kr/seoji/SearchApi.do';

/**
 * 국립중앙도서관 서지정보유통지원시스템(seoji) API로 목차 조회.
 *
 * - 출판사가 ISBN 등록 시 제출하는 메타데이터로,
 *   TABLE_OF_CONTENTS 필드에 목차가 있는 책이 있음.
 * - 긴 목차는 BOOK_TB_CNT_URL로 별도 텍스트 파일 링크 제공.
 *
 * 인증키 신청: https://www.nl.go.kr/seoji/contents/S80100000000.do
 */
export async function fetchNlk(
  isbn: string,
  debug = false,
): Promise<NlkResult> {
  const key = Deno.env.get('NLK_CERT_KEY') ?? '';
  if (!key) {
    return debug
      ? { toc: [], _debug: { hasKey: false, found: false } }
      : { toc: [] };
  }

  const clean = isbn.replace(/[^0-9Xx]/g, '');
  if (!clean) return { toc: [] };

  const params = new URLSearchParams({
    cert_key: key,
    result_style: 'json',
    page_no: '1',
    page_size: '10',
    isbn: clean,
  });

  const res = await fetch(`${ENDPOINT}?${params.toString()}`);
  if (!res.ok) throw new Error(`NLK API error: ${res.status}`);

  const body = await res.json();
  const docs = body?.docs ?? [];
  if (docs.length === 0) {
    return debug
      ? { toc: [], _debug: { hasKey: true, found: false } }
      : { toc: [] };
  }

  const doc = docs[0];
  let tocText: string = doc?.TABLE_OF_CONTENTS ?? '';
  let fromUrl = false;

  // 짧은 목차는 본문에, 긴 목차는 별도 URL로 제공
  if (!tocText) {
    const tocUrl = doc?.BOOK_TB_CNT_URL ?? '';
    if (tocUrl) {
      try {
        const r = await fetch(tocUrl);
        if (r.ok) {
          tocText = await r.text();
          fromUrl = true;
        }
      } catch (_) {
        // ignore
      }
    }
  }

  const toc = parseTocText(tocText);

  return {
    toc,
    ...(debug
      ? {
          _debug: {
            hasKey: true,
            found: true,
            rawTocLen: tocText.length,
            fromUrl,
          },
        }
      : {}),
  };
}

function parseTocText(s: string): string[] {
  if (!s) return [];
  return s
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/?[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .split(/[\n;]/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0 && l.length < 200);
}
