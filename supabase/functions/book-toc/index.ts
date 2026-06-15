// 책 메타데이터 통합 프록시
//
// 알라딘: TOC(있을 때) + 가격 + 구매 링크
// 교보문고: 정보 보기 링크 (TOC 스크래핑 안 함)
//
// 응답: {
//   toc: string[],
//   tocSource: 'aladin' | null,
//   priceStandard?: number,
//   priceSales?: number,
//   aladinLink?: string,
//   kyoboLink?: string,
// }

import { corsHeaders } from '../_shared/cors.ts';
import { fetchAladin } from './aladin.ts';
import { fetchKyobo } from './kyobo.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const isbn = url.searchParams.get('isbn')?.trim() ?? '';
    const title = url.searchParams.get('title')?.trim() ?? '';
    const debug = url.searchParams.get('debug') === '1';

    if (!isbn && !title) {
      return json({ error: 'isbn or title is required' }, 400);
    }

    const out: Record<string, unknown> = {
      toc: [],
      tocSource: null,
    };

    if (isbn) {
      try {
        const a = await fetchAladin(isbn, debug);
        if (Array.isArray(a.toc) && a.toc.length > 0) {
          out.toc = a.toc;
          out.tocSource = 'aladin';
        }
        if (a.priceStandard != null) out.priceStandard = a.priceStandard;
        if (a.priceSales != null) out.priceSales = a.priceSales;
        if (a.link) out.aladinLink = a.link;
        if (debug) {
          out._aladinDebug = { rawToc: a._rawToc, hasSubInfo: a._hasSubInfo };
        }
      } catch (e) {
        if (debug) out._aladinError = String(e);
        console.error('Aladin failed:', e);
      }
    }

    try {
      const k = await fetchKyobo(isbn, title, debug);
      if (k.link) out.kyoboLink = k.link;
      if (debug) out._kyoboDebug = k._debug;
    } catch (e) {
      if (debug) out._kyoboError = String(e);
      console.error('Kyobo failed:', e);
    }

    return json(out);
  } catch (e) {
    console.error('Unhandled error:', e);
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
