// 의존성 없는 최소 RSS/Atom 파서.
//
// 대부분의 한국 언론사 및 구글뉴스 RSS 가 <item> 형식이라 이걸로 충분하다.
// 정교한 파싱이 필요해지면 deno_dom 등으로 교체.

export interface RssArticle {
  title: string;
  summary: string;
  link: string;
  source: string;
  publishedAt: string | null;
  imageUrl: string | null;
}

function decodeEntities(s: string): string {
  return s
    .replace(/<!\[CDATA\[(.*?)\]\]>/gs, '$1')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

function stripTags(s: string): string {
  return decodeEntities(s.replace(/<[^>]*>/g, '')).trim();
}

function pick(block: string, tag: string): string | null {
  const m = block.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, 'i'));
  return m ? m[1].trim() : null;
}

function pickAttr(block: string, tag: string, attr: string): string | null {
  const m = block.match(new RegExp(`<${tag}[^>]*\\b${attr}=["']([^"']+)["']`, 'i'));
  return m ? m[1] : null;
}

export function parseRss(xml: string, sourceFallback: string): RssArticle[] {
  const channelTitle = pick(xml, 'title');
  const source = channelTitle ? stripTags(channelTitle) : sourceFallback;

  const blocks = xml.match(/<item[\s\S]*?<\/item>/gi) ??
    xml.match(/<entry[\s\S]*?<\/entry>/gi) ??
    [];

  const out: RssArticle[] = [];
  for (const block of blocks) {
    const rawTitle = pick(block, 'title');
    // RSS: <link>url</link>  /  Atom: <link href="url"/>
    const link = pick(block, 'link') || pickAttr(block, 'link', 'href') || '';
    const desc = pick(block, 'description') || pick(block, 'summary') || '';
    const pub = pick(block, 'pubDate') || pick(block, 'published') ||
      pick(block, 'updated');
    const image = pickAttr(block, 'media:content', 'url') ||
      pickAttr(block, 'media:thumbnail', 'url') ||
      pickAttr(block, 'enclosure', 'url');

    if (!rawTitle || !link) continue;

    out.push({
      title: stripTags(rawTitle),
      summary: stripTags(desc).slice(0, 200),
      link: decodeEntities(link.trim()),
      source,
      publishedAt: pub ? new Date(pub).toISOString() : null,
      imageUrl: image,
    });
  }
  return out;
}
