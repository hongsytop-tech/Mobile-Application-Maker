export interface AladinResult {
  toc: string[];
  priceStandard?: number;
  priceSales?: number;
  link?: string;
  _rawToc?: string;
  _hasSubInfo?: boolean;
}

const ENDPOINT = 'https://www.aladin.co.kr/ttb/api/ItemLookUp.aspx';

export async function fetchAladin(
  isbn: string,
  debug = false,
): Promise<AladinResult> {
  const ttbKey = Deno.env.get('ALADIN_TTB_KEY') ?? '';
  if (!ttbKey) throw new Error('ALADIN_TTB_KEY is not set on Supabase secrets');

  const clean = isbn.replace(/[^0-9Xx]/g, '');
  if (!clean) return { toc: [] };

  const params = new URLSearchParams({
    ttbkey: ttbKey,
    itemIdType: clean.length === 13 ? 'ISBN13' : 'ISBN',
    ItemId: clean,
    output: 'js',
    Version: '20131101',
    OptResult: 'Toc',
  });

  const res = await fetch(`${ENDPOINT}?${params.toString()}`);
  if (!res.ok) throw new Error(`Aladin API error: ${res.status}`);

  const text = await res.text();
  const body = safeJson(text);
  if (!body || body.errorCode) {
    throw new Error(`Aladin: ${body?.errorMessage ?? 'unknown error'}`);
  }

  const items = body.item ?? [];
  if (items.length === 0) return { toc: [] };

  const item = items[0];
  const sub = item.subInfo ?? {};
  const toc = parseTocHtml(sub.toc ?? '');

  return {
    toc,
    priceStandard: item.priceStandard,
    priceSales: item.priceSales,
    link: item.link,
    ...(debug
      ? {
          _rawToc: typeof sub.toc === 'string' ? sub.toc.slice(0, 500) : '',
          _hasSubInfo: !!item.subInfo,
        }
      : {}),
  };
}

function safeJson(raw: string): any {
  let s = raw.trim();
  if (s.endsWith(';')) s = s.slice(0, -1);
  s = s.replace(/,\s*([}\]])/g, '$1');
  try {
    return JSON.parse(s);
  } catch {
    return null;
  }
}

function parseTocHtml(html: string): string[] {
  if (!html) return [];
  return html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p\s*>/gi, '\n')
    .replace(/<\/li\s*>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .split('\n')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}
