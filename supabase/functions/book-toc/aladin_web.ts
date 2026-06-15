export interface AladinWebResult {
  toc: string[];
  _debug?: {
    htmlLength: number;
    itemId?: string;
    matchedPattern?: number;
    tocKeywordIndices?: number[];
    tocSnippets?: string[];
  };
}

const UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

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

  const patterns: RegExp[] = [
    /<div[^>]*id="div_TOC_All"[^>]*>([\s\S]*?)<\/div>\s*<\/div>/i,
    /<div[^>]*id="div_TOC[_A-Za-z0-9]*"[^>]*>([\s\S]*?)<\/div>/i,
    /<div[^>]*id="Ere_prod_mconts_LF_T"[^>]*>([\s\S]*?)<\/div>/i,
    /<div[^>]*class="[^"]*conts_info_list1[^"]*"[^>]*>([\s\S]*?)<\/div>/i,
    /목차\s*<\/h[1-6][^>]*>\s*<div[^>]*>([\s\S]*?)<\/div>/i,
    /목차\s*<\/(?:b|strong|span|h\d)>([\s\S]{50,5000}?)(?:저자\s*소개|책\s*속에서|출판사\s*리뷰|<\/section>)/i,
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

  let tocKeywordIndices: number[] | undefined;
  let tocSnippets: string[] | undefined;
  if (debug) {
    tocKeywordIndices = [];
    let i = -1;
    while ((i = html.indexOf('목차', i + 1)) !== -1) {
      tocKeywordIndices.push(i);
      if (tocKeywordIndices.length >= 5) break;
    }
    tocSnippets = tocKeywordIndices.map((idx) =>
      html.substring(idx, Math.min(idx + 1500, html.length)),
    );
  }

  return {
    toc,
    ...(debug
      ? {
          _debug: {
            htmlLength: html.length,
            itemId,
            matchedPattern: matched,
            tocKeywordIndices,
            tocSnippets,
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
