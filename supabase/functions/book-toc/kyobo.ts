export interface KyoboResult {
  toc: string[];
  link?: string;
  _debug?: {
    fetchedUrl?: string;
    htmlLength: number;
    productMatched: boolean;
    hasTocKeyword?: boolean;
    tocKeywordCount?: number;
    tocSnippets?: string[];
    isSpa?: boolean;
    matchedPattern?: number;
  };
}

const UA_DESKTOP =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const UA_MOBILE =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 ' +
  '(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

/**
 * 교보문고 상품 페이지에서 목차 시도.
 *
 * - productUrl이 직접 주어지면 그 URL로 바로 fetch (디버그용)
 * - 그렇지 않으면 검색 → 상품 URL 추출 → 상세 페이지 fetch 흐름
 */
export async function fetchKyobo(
  isbn: string,
  title: string,
  debug = false,
  productUrlOverride?: string,
): Promise<KyoboResult> {
  let productUrl = productUrlOverride;
  let productMatched = false;

  if (!productUrl) {
    const keyword = isbn || title;
    if (!keyword) return { toc: [] };
    const searchUrl =
      `https://search.kyobobook.co.kr/search?keyword=${encodeURIComponent(keyword)}` +
      `&gbCode=TOT&target=total`;
    const searchHtml = await fetchHtml(searchUrl, UA_DESKTOP);
    const m = searchHtml.match(
      /https:\/\/product\.kyobobook\.co\.kr\/detail\/[A-Z0-9]+/i,
    );
    if (m) {
      productUrl = m[0];
      productMatched = true;
    }
  } else {
    productMatched = true;
  }

  if (!productUrl) {
    return debug
      ? {
          toc: [],
          _debug: {
            htmlLength: 0,
            productMatched: false,
          },
        }
      : { toc: [] };
  }

  // 데스크톱 + 모바일 둘 다 시도, 더 큰/유용한 것 선택
  let html = '';
  let triedUa = UA_DESKTOP;
  try {
    html = await fetchHtml(productUrl, UA_DESKTOP);
    if (!html.includes('목차') || html.length < 5000) {
      // 데스크톱이 부실하면 모바일도 시도
      try {
        const mobileHtml = await fetchHtml(productUrl, UA_MOBILE);
        if (mobileHtml.length > html.length || mobileHtml.includes('목차')) {
          html = mobileHtml;
          triedUa = UA_MOBILE;
        }
      } catch (_) {
        // ignore
      }
    }
  } catch (_) {
    // ignore
  }

  const tocResult = extractToc(html);
  const dbg: NonNullable<KyoboResult['_debug']> = {
    fetchedUrl: productUrl,
    htmlLength: html.length,
    productMatched,
  };

  if (debug) {
    const indices: number[] = [];
    let i = -1;
    while ((i = html.indexOf('목차', i + 1)) !== -1) {
      indices.push(i);
      if (indices.length >= 5) break;
    }
    dbg.hasTocKeyword = indices.length > 0;
    dbg.tocKeywordCount = indices.length;
    dbg.tocSnippets = indices.map((idx) =>
      html.substring(idx, Math.min(idx + 1200, html.length)),
    );
    // SPA 마커 감지
    dbg.isSpa =
      /__NEXT_DATA__|<div id="__nuxt"|<div id="root"|window\.__INITIAL_STATE__/.test(
        html,
      );
    dbg.matchedPattern = tocResult.pattern;
  }

  return {
    toc: tocResult.toc,
    link: productUrl,
    ...(debug ? { _debug: dbg } : {}),
  };
}

async function fetchHtml(url: string, ua: string): Promise<string> {
  const res = await fetch(url, {
    headers: {
      'User-Agent': ua,
      'Accept-Language': 'ko-KR,ko;q=0.9',
      'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Cache-Control': 'no-cache',
    },
  });
  return await res.text();
}

function extractToc(html: string): { toc: string[]; pattern: number } {
  if (!html.includes('목차')) return { toc: [], pattern: -1 };

  // 교보문고 상품 페이지 목차 섹션 후보 패턴
  const patterns: RegExp[] = [
    // 신 페이지 (product.kyobobook.co.kr)
    /<div[^>]*class="[^"]*book_contents_box[^"]*"[^>]*>([\s\S]*?)<\/div>\s*<\/div>/i,
    /<ul[^>]*class="[^"]*book_contents_list[^"]*"[^>]*>([\s\S]*?)<\/ul>/i,
    /<div[^>]*id="scrollSpyProductInfo"[^>]*>[\s\S]*?목차[\s\S]*?<div[^>]*>([\s\S]*?)<\/div>/i,
    /<h3[^>]*>\s*목차\s*<\/h3>\s*<div[^>]*>([\s\S]*?)<\/div>/i,
    /목차\s*<\/(?:h\d|strong|span|div|p)>\s*<(?:div|ul|p)[^>]*>([\s\S]{50,8000}?)<\/(?:div|ul|p)>/i,
    /<div[^>]*class="[^"]*\bcontents_info\b[^"]*"[^>]*>([\s\S]*?)<\/div>/i,
    /목차[\s\S]{0,200}?<pre[^>]*>([\s\S]*?)<\/pre>/i,
  ];

  for (let i = 0; i < patterns.length; i++) {
    const m = html.match(patterns[i]);
    if (m) {
      const lines = stripHtml(m[1])
        .split('\n')
        .map((s) => s.trim())
        .filter((s) => s.length > 0 && s.length < 200);
      const hasKorean = lines.some((l) => /[가-힣]/.test(l));
      const looksLikeBookMeta =
        lines.length <= 6 &&
        lines.every((l) =>
          /(\d+쪽|ISBN|mm|cm|g$|\d+x\d+|\d{4}-\d{2}-\d{2})/.test(l),
        );
      if (lines.length > 1 && hasKorean && !looksLikeBookMeta) {
        return { toc: lines, pattern: i };
      }
    }
  }
  return { toc: [], pattern: -1 };
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
