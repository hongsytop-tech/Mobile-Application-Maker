// 책 메타데이터 통합 프록시
//
// TOC 폴백 체인: 알라딘 API → 알라딘 웹 → 국립중앙도서관(seoji) → (교보문고 TOC는 봇 차단으로 포기)
// 알라딘: 가격 + 구매 링크
// 교보문고: 정보 보기 링크만
//
// 응답: {
//   toc: string[],
//   tocSource: 'aladin' | 'aladin_web' | 'nlk' | null,
//   priceStandard?: number,
//   priceSales?: number,
//   aladinLink?: string,
//   kyoboLink?: string,
// }

import { corsHeaders } from '../_shared/cors.ts';
import { fetchAladin } from './aladin.ts';
import { fetchAladinWebToc } from './aladin_web.ts';
import { fetchKyobo } from './kyobo.ts';
import { fetchNlk } from './nlk.ts';

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

    // 1. 알라딘 API (가격·링크는 항상, TOC는 있을 때만)
    let aladinLink: string | undefined;
    if (isbn) {
      try {
        const a = await fetchAladin(isbn, debug);
        if (Array.isArray(a.toc) && a.toc.length > 0) {
          out.toc = a.toc;
          out.tocSource = 'aladin';
        }
        if (a.priceStandard != null) out.priceStandard = a.priceStandard;
        if (a.priceSales != null) out.priceSales = a.priceSales;
        if (a.link) {
          out.aladinLink = a.link;
          aladinLink = a.link;
        }
        if (debug) {
          out._aladinDebug = { rawToc: a._rawToc, hasSubInfo: a._hasSubInfo };
        }
      } catch (e) {
        if (debug) out._aladinError = String(e);
        console.error('Aladin failed:', e);
      }
    }

    // 2. 알라딘 웹 페이지 스크래핑 (TOC가 비어있을 때)
    if ((out.toc as string[]).length === 0 && aladinLink) {
      try {
        const w = await fetchAladinWebToc(aladinLink, debug);
        if (w.toc.length > 0) {
          out.toc = w.toc;
          out.tocSource = 'aladin_web';
        }
        if (debug) out._aladinWebDebug = w._debug;
      } catch (e) {
        if (debug) out._aladinWebError = String(e);
        console.error('Aladin web failed:', e);
      }
    }

    // 3. 국립중앙도서관 seoji (TOC가 여전히 비어있을 때)
    if ((out.toc as string[]).length === 0 && isbn) {
      try {
        const n = await fetchNlk(isbn, debug);
        if (n.toc.length > 0) {
          out.toc = n.toc;
          out.tocSource = 'nlk';
        }
        if (debug) out._nlkDebug = n._debug;
      } catch (e) {
        if (debug) out._nlkError = String(e);
        console.error('NLK failed:', e);
      }
    }

    // 4. 교보문고 (정보 링크만)
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
