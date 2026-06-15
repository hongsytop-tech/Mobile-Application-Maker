// 책 목차(TOC) 통합 프록시
//
// 흐름: 알라딘 → 교보문고 (둘 다 실패 시 빈 결과)
// 응답: { source: 'aladin' | 'kyobo' | null, toc: string[], priceStandard?, priceSales?, link? }

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

    if (!isbn && !title) {
      return json({ error: 'isbn or title is required' }, 400);
    }

    // 1. 알라딘 (ISBN 필요)
    if (isbn) {
      try {
        const r = await fetchAladin(isbn);
        if (r.toc.length > 0) {
          return json({ source: 'aladin', ...r });
        }
      } catch (e) {
        console.error('Aladin failed:', e);
      }
    }

    // 2. 교보문고
    try {
      const r = await fetchKyobo(isbn, title);
      if (r.toc.length > 0) {
        return json({ source: 'kyobo', ...r });
      }
    } catch (e) {
      console.error('Kyobo failed:', e);
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
