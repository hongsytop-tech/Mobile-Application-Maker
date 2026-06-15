export interface KyoboResult {
  toc: string[];
  link?: string;
  _debug?: {
    htmlLength: number;
    hasTocKeyword: boolean;
    snippet?: string;
    productMatched?: boolean;
  };
}

const UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/**
 * 교보문고 도서 페이지에서 목차를 best-effort로 추출.
 *
 * 주의:
 * - 교보문고는 공식 API가 없어 HTML 구조 변경에 취약합니다.
 * - 요청 빈도를 낮게 유지하고 캐시를 사용하세요.
 * - 상용 서비스 시 robots.txt / 이용약관을 반드시 확인하세요.
 */
export async function fetchKyobo(
  isbn: string,
  title: string,
  debug = false,
): Promise<KyoboResult> {
  const keyword = isbn || title;
  if (!keyword) return { toc: [] };

  // 1. 검색 페이지로 상품 ID 찾기
  const searchUrl =
    `https://search.kyobobook.co.kr/search?keyword=${encodeURIComponent(keyword)}` +
    `&gbCode=TOT&target=total`;
  const searchHtml = await fetchText(searchUrl);

  // 상품 상세 URL 추출
  const productMatch = searchHtml.match(
    /https:\/\/product\.kyobobook\.co\.kr\/detail\/[A-Z0-9]+/i,
  );
  if (!productMatch) {
    return debug
      ? {
          toc: [],
          _debug: {
            htmlLength: searchHtml.length,
            hasTocKeyword: false,
            productMatched: false,
          },
        }
      : { toc: [] };
  }
  const productUrl = productMatch[0];

  // 2. 상세 페이지에서 목차 추출
  const productHtml = await fetchText(productUrl);
  const toc = extractToc(productHtml);

  const result: KyoboResult = { toc, link: productUrl };
  if (debug) {
    const idx = productHtml.indexOf('목차');
    result._debug = {
      htmlLength: productHtml.length,
      hasTocKeyword: idx >= 0,
      snippet:
        idx >= 0 ? productHtml.substring(idx, Math.min(idx + 800, productHtml.length)) : undefined,
      productMatched: true,
    };
  }
  return result;
}

async function fetchText(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: {
      'User-Agent': UA,
      'Accept-Language': 'ko-KR,ko;q=0.9',
    },
  });
  if (!res.ok) throw new Error(`Fetch ${url} → ${res.status}`);
  return await res.text();
}

function extractToc(html: string): string[] {
  // 교보문고 상세 페이지 목차 섹션 후보 패턴들
  const candidates: RegExp[] = [
    /<div[^>]*class="[^"]*book_contents_box[^"]*"[^>]*>([\s\S]*?)<\/div>\s*<\/div>/i,
    /<div[^>]*id="container_modal_tab_index"[^>]*>([\s\S]*?)<\/div>/i,
    /<div[^>]*class="[^"]*\bbook_index\b[^"]*"[^>]*>([\s\S]*?)<\/div>/i,
    /목차\s*<\/[^>]+>\s*<div[^>]*>([\s\S]*?)<\/div>/i,
  ];

  for (const re of candidates) {
    const m = html.match(re);
    if (m) {
      const lines = stripHtml(m[1])
        .split('\n')
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
      if (lines.length > 1) return lines;
    }
  }
  return [];
}

function stripHtml(s: string): string {
  return s
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p\s*>/gi, '\n')
    .replace(/<\/li\s*>/gi, '\n')
    .replace(/<\/div\s*>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}
