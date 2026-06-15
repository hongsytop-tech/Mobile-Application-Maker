import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface CachedMeta {
  toc: string[];
  tocSource: string | null;
  priceStandard?: number;
  priceSales?: number;
  aladinLink?: string;
  kyoboLink?: string;
}

let _client: SupabaseClient | null = null;

function client(): SupabaseClient | null {
  if (_client) return _client;
  const url = Deno.env.get('SUPABASE_URL') ?? '';
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!url || !key) return null;
  _client = createClient(url, key, {
    auth: { persistSession: false },
  });
  return _client;
}

/** 캐시 조회. 만료됐거나 없으면 null. */
export async function getCached(isbn: string): Promise<CachedMeta | null> {
  const c = client();
  if (!c || !isbn) return null;
  const { data, error } = await c
    .from('book_toc_cache')
    .select('*')
    .eq('isbn', isbn)
    .maybeSingle();
  if (error || !data) return null;
  if (new Date(data.expires_at).getTime() < Date.now()) return null;
  return {
    toc: (data.toc as string[]) ?? [],
    tocSource: data.toc_source ?? null,
    priceStandard: data.price_standard ?? undefined,
    priceSales: data.price_sales ?? undefined,
    aladinLink: data.aladin_link ?? undefined,
    kyoboLink: data.kyobo_link ?? undefined,
  };
}

/** 캐시 저장 (upsert). 의미있는 데이터가 있을 때만. */
export async function setCached(isbn: string, meta: CachedMeta): Promise<void> {
  const c = client();
  if (!c || !isbn) return;
  const hasData =
    meta.toc.length > 0 ||
    meta.priceStandard != null ||
    meta.priceSales != null ||
    meta.aladinLink != null ||
    meta.kyoboLink != null;
  if (!hasData) return;

  const now = new Date();
  const expires = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
  await c.from('book_toc_cache').upsert({
    isbn,
    toc: meta.toc,
    toc_source: meta.tocSource,
    price_standard: meta.priceStandard ?? null,
    price_sales: meta.priceSales ?? null,
    aladin_link: meta.aladinLink ?? null,
    kyobo_link: meta.kyoboLink ?? null,
    cached_at: now.toISOString(),
    expires_at: expires.toISOString(),
  });
}
