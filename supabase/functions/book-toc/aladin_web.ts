export interface AladinWebResult {
  toc: string[];
  _debug?: {
    htmlLength: number;
    itemId?: string;
    matchedPattern?: number;
  };
}

const UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/**
 * 알라딘 상품 페이지(SSR)를 스크래핑하여 목차 추출.
 * API에서는 TOC를 제공하지 않는 책도 웹 페이지에 표시되는 경우가 많음.
 */
export async function fetchAladinWebToc(
  aladinLink: string | undefined,
  debug = false,
): Promise<AladinWebResult> {
  if (!aladinLink) return { toc: [] };
  const idMatch = aladinLink.match(/ItemId=(\d+)/);
  if (!idMatch) return { toc: [] };
  const itemId = idMatch[1];

  const url = `https://www.aladin.co.kr/shop/wproduct.aspx?ItemId=${itemId}`;
  const res = await fetch(url, {
    headers: {
      'User-Agent': UA,
      'Accept-Language': 'ko-KR,ko;q=0.9',
    },
  });
  const html = await res.text();

  // 알라딘 상세페이지 목차 섹션 후보 패턴
  const patterns: RegExp[] = [
    /<div[^>]*id="div_TOC_All"[^>]*>([\s\S]*?)<\/div>\s*<\/div>/i,
    /<div[^>]*id="div_TOC[_A-Za-z0-9]*"[^>]*>([\s\S]*?)<\/div>/i,
    /목차\s*<\/h[1-6][^>]*>\s*<div[^>]*>([\s\S]*?)<\/div>/i,
    /<div[^>]*class="[^"]*Ere_prod_mconts_LF[^"]*"[^>]*>[\s\S]*?목차[\s\S]*?<div[^>]*>([\s\S]*?)<\/div>/i,
  ];

  let toc: string[] = [];
  let matched = -1;
  for (let i = 0; i < patterns.length; i++) {
    const m = html.match(patterns[i]);
    if (m) {
      const lines = stripHtml(m[1])
        .split('\n')
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
      if (lines.length > 1) {
        toc = lines;
        matched = i;
        break;
      }
    }
  }

  return {
    toc,
    ...(debug
      ? {
          _debug: {
            htmlLength: html.length,
            itemId,
            matchedPattern: matched,
          },
        }
      : {}),
  };
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
