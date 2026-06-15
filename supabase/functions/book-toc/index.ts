// 책 메타데이터 통합 프록시
//
// 캐시: ISBN으로 Postgres 캐시 조회 → HIT면 즉시 반환, MISS면 폴백 체인 후 저장
// TOC 폴백 체인: 알라딘 API → 알라딘 웹 → 국립중앙도서관(seoji) → 교보문고 SSR
// 가격·구매 링크: 알라딘 API / 교보문고 링크
//
// 쿼리: ?isbn= &title= &kyoboUrl=(디버그) &debug=1 &nocache=1
// 응답: {
//   toc: string[],
//   tocSource: 'aladin' | 'aladin_web' | 'nlk' | 'kyobo' | null,
//   priceStandard?, priceSales?, aladinLink?, kyoboLink?,
//   cached?: boolean (debug)
// }

import { corsHeaders } from '../_shared/cors.ts';
import { fetchAladin } from './aladin.ts';
import { fetchAladinWebToc } from './aladin_web.ts';
import { fetchKyobo } from './kyobo.ts';
import { fetchNlk } from './nlk.ts';
import { getCached, setCached } from './cache.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const isbn = url.searchParams.get('isbn')?.trim() ?? '';
    const title = url.searchParams.get('title')?.trim() ?? '';
    const debug = url.searchParams.get('debug') === '1';
    const nocache = url.searchParams.get('nocache') === '1';
    const kyoboUrl = url.searchParams.get('kyoboUrl')?.trim() ?? '';

    if (!isbn && !title && !kyoboUrl) {
      return json({ error: 'isbn, title, or kyoboUrl is required' }, 400);
    }

    // 0. 캐시 조회 (ISBN 있고, 강제갱신/직접URL 디버그가 아닐 때)
    if (isbn && !nocache && !kyoboUrl) {
      try {
        const cached = await getCached(isbn);
        if (cached) {
          return json(debug ? { ...cached, cached: true } : cached);
        }
      } catch (e) {
        console.error('Cache read failed:', e);
      }
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

    // 4. 교보문고 (TOC 시도 + 정보 링크)
    if ((out.toc as string[]).length === 0 || kyoboUrl) {
      try {
        const k = await fetchKyobo(isbn, title, debug, kyoboUrl || undefined);
        if (k.toc.length > 0) {
          out.toc = k.toc;
          out.tocSource = 'kyobo';
        }
        if (k.link) out.kyoboLink = k.link;
        if (debug) out._kyoboDebug = k._debug;
      } catch (e) {
        if (debug) out._kyoboError = String(e);
        console.error('Kyobo failed:', e);
      }
    } else {
      // TOC가 이미 있으면 링크만 가져옴
      try {
        const k = await fetchKyobo(isbn, title, debug);
        if (k.link) out.kyoboLink = k.link;
        if (debug) out._kyoboDebug = k._debug;
      } catch (e) {
        if (debug) out._kyoboError = String(e);
      }
    }

    // 5. 캐시 저장 (ISBN 있을 때)
    if (isbn && !kyoboUrl) {
      try {
        await setCached(isbn, {
          toc: out.toc as string[],
          tocSource: out.tocSource as string | null,
          priceStandard: out.priceStandard as number | undefined,
          priceSales: out.priceSales as number | undefined,
          aladinLink: out.aladinLink as string | undefined,
          kyoboLink: out.kyoboLink as string | undefined,
        });
      } catch (e) {
        console.error('Cache write failed:', e);
      }
    }

    return json(debug ? { ...out, cached: false } : out);
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
