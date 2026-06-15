export interface KyoboResult {
  link?: string;
  _debug?: {
    htmlLength: number;
    productMatched: boolean;
  };
}

const UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/**
 * 교보문고 상품 상세 페이지 URL을 찾아 반환.
 * (TOC 스크래핑은 봇 차단으로 불가하여 정보 보기 링크만 제공)
 */
export async function fetchKyobo(
  isbn: string,
  title: string,
  debug = false,
): Promise<KyoboResult> {
  const keyword = isbn || title;
  if (!keyword) return {};

  const searchUrl =
    `https://search.kyobobook.co.kr/search?keyword=${encodeURIComponent(keyword)}` +
    `&gbCode=TOT&target=total`;
  const res = await fetch(searchUrl, {
    headers: {
      'User-Agent': UA,
      'Accept-Language': 'ko-KR,ko;q=0.9',
    },
  });
  const html = await res.text();

  const m = html.match(
    /https:\/\/product\.kyobobook\.co\.kr\/detail\/[A-Z0-9]+/i,
  );
  const link = m ? m[0] : undefined;

  return {
    link,
    ...(debug
      ? {
          _debug: {
            htmlLength: html.length,
            productMatched: !!link,
          },
        }
      : {}),
  };
}
