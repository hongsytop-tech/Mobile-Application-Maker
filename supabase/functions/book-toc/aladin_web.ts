export interface AladinWebResult {
  toc: string[];
  _debug?: {
    desktopHtmlLength?: number;
    mobileHtmlLength?: number;
    itemId?: string;
    matchedSource?: 'desktop' | 'mobile' | null;
    matchedPattern?: number;
    desktopHasTocKeyword?: boolean;
    mobileHasTocKeyword?: boolean;
    mobileSnippet?: string;
  };
}

const UA =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 ' +
  '(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
const UA_DESKTOP =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/**
 * 알라딘 모바일 페이지를 우선 시도(SSR 가능성 높음), 실패 시 데스크톱 시도.
 * 목차는 데스크톱 페이지에서 JS로 후속 로드되므로 SSR 추출 불가.
 */
export async function fetchAladinWebToc(
  aladinLink: string | undefined,
  debug = false,
): Promise<AladinWebResult> {
  if (!aladinLink) return { toc: [] };
  const idMatch = aladinLink.match(/ItemId=(\d+)/);
  if (!idMatch) return { toc: [] };
  const itemId = idMatch[1];

  const dbg: NonNullable<AladinWebResult['_debug']> = {
    itemId,
    matchedSource: null,
    matchedPattern: -1,
  };

  // 1. 모바일 페이지 시도
  const mobileUrl = `https://www.aladin.co.kr/m/mproduct.aspx?ItemId=${itemId}`;
  let toc: string[] = [];
  try {
    const html = await fetchHtml(mobileUrl, UA);
    if (debug) {
      dbg.mobileHtmlLength = html.length;
      dbg.mobileHasTocKeyword = html.includes('목차');
      const idx = html.indexOf('목차');
      if (idx >= 0) dbg.mobileSnippet = html.substring(idx, idx + 1500);
    }
    const r = extractToc(html);
    if (r.toc.length > 0) {
      toc = r.toc;
      dbg.matchedSource = 'mobile';
      dbg.matchedPattern = r.pattern;
    }
  } catch (_) {
    // ignore
  }

  // 2. 모바일에서 못 찾았으면 데스크톱 시도
  if (toc.length === 0) {
    const desktopUrl = `https://www.aladin.co.kr/shop/wproduct.aspx?ItemId=${itemId}`;
    try {
      const html = await fetchHtml(desktopUrl, UA_DESKTOP);
      if (debug) {
        dbg.desktopHtmlLength = html.length;
        dbg.desktopHasTocKeyword = html.includes('목차');
      }
      const r = extractToc(html);
      if (r.toc.length > 0) {
        toc = r.toc;
        dbg.matchedSource = 'desktop';
        dbg.matchedPattern = r.pattern;
      }
    } catch (_) {
      // ignore
    }
  }

  return {
    toc,
    ...(debug ? { _debug: dbg } : {}),
  };
}

async function fetchHtml(url: string, ua: string): Promise<string> {
  const res = await fetch(url, {
    headers: {
      'User-Agent': ua,
      'Accept-Language': 'ko-KR,ko;q=0.9',
    },
  });
  return await res.text();
}

/**
 * 목차 추출 — "목차" 키워드가 없으면 즉시 포기 (false positive 방지)
 */
function extractToc(html: string): { toc: string[]; pattern: number } {
  if (!html.includes('목차')) return { toc: [], pattern: -1 };

  const patterns: RegExp[] = [
    /<div[^>]*id="div_TOC_All"[^>]*>([\s\S]*?)<\/div>\s*<\/div>/i,
    /<div[^>]*id="div_TOC[_A-Za-z0-9]*"[^>]*>([\s\S]*?)<\/div>/i,
    /<div[^>]*id="Ere_prod_mconts_LF_T"[^>]*>([\s\S]*?)<\/div>/i,
    /목차\s*<\/h[1-6][^>]*>\s*<div[^>]*>([\s\S]*?)<\/div>/i,
    /목차\s*<\/(?:b|strong|span|h\d|td|th)>([\s\S]{50,8000}?)(?:저자\s*소개|책\s*속에서|출판사\s*리뷰|<\/section>)/i,
    /<h\d[^>]*>\s*목차\s*<\/h\d>\s*([\s\S]{50,8000}?)<h\d/i,
  ];

  for (let i = 0; i < patterns.length; i++) {
    const m = html.match(patterns[i]);
    if (m) {
      const lines = stripHtml(m[1])
        .split('\n')
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
      const hasKorean = lines.some((l) => /[가-힣]/.test(l));
      // 책 정보(쪽수·ISBN·크기) 같은 false positive 패턴 거르기
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
