// 책 목차(TOC) 통합 프록시
//
// 흐름: 알라딘 → 교보문고 (둘 다 실패 시 빈 결과)
// 응답: { source: 'aladin' | 'kyobo' | null, toc: string[], priceStandard?, priceSales?, link? }
//
// 디버그: ?debug=1 추가 시 알라딘·교보문고 양쪽 결과/에러를 그대로 반환.

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

    let aladinResult: unknown = null;
    let aladinError: string | null = null;
    if (isbn) {
      try {
        aladinResult = await fetchAladin(isbn);
      } catch (e) {
        aladinError = String(e);
        console.error('Aladin failed:', e);
      }
    }

    let kyoboResult: unknown = null;
    let kyoboError: string | null = null;
    try {
      kyoboResult = await fetchKyobo(isbn, title);
    } catch (e) {
      kyoboError = String(e);
      console.error('Kyobo failed:', e);
    }

    if (debug) {
      return json({
        isbn,
        title,
        aladin: aladinResult,
        aladinError,
        kyobo: kyoboResult,
        kyoboError,
        hasAladinKey: !!Deno.env.get('ALADIN_TTB_KEY'),
      });
    }

    const aladin = aladinResult as { toc?: string[] } | null;
    if (aladin && Array.isArray(aladin.toc) && aladin.toc.length > 0) {
      return json({ source: 'aladin', ...aladin });
    }
    const kyobo = kyoboResult as { toc?: string[] } | null;
    if (kyobo && Array.isArray(kyobo.toc) && kyobo.toc.length > 0) {
      return json({ source: 'kyobo', ...kyobo });
    }

    return json({ source: null, toc: [] });
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
