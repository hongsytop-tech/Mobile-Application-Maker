// 뉴스 크롤링 통합 프록시 (스켈레톤)
//
// 브라우저(웹)에서는 CORS로 외부 뉴스 사이트를 직접 못 긁으므로,
// 독서 모듈(book-toc)과 동일하게 서버에서 대신 가져와 정규화한다.
//
// 쿼리: ?feed=top  (feeds.ts 에 정의된 키)  &q=검색어  &nocache=1
// 응답: { articles: NewsArticle[], feed: string, error?: string }
//   NewsArticle = { title, summary, link, source, publishedAt, imageUrl }
//
// TODO(news): 소스 확정 후 feeds.ts 의 url 채우기.
//   - RSS 소스: feeds.ts 에 url 추가하면 끝
//   - 스크래핑 필요 소스(예: 네이버 뉴스 검색): kind='scrape' 분기에 파서 추가

import { corsHeaders } from '../_shared/cors.ts';
import { parseRss } from './rss.ts';
import { resolveFeed } from './feeds.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const feedKey = url.searchParams.get('feed')?.trim() || 'top';
    const query = url.searchParams.get('q')?.trim() ?? '';

    const feed = resolveFeed(feedKey);
    if (!feed) {
      return json({ error: `unknown feed: ${feedKey}`, articles: [] }, 400);
    }

    if (feed.kind === 'rss') {
      if (!feed.url) {
        // 소스 미설정 — 클라이언트가 안내 문구를 띄울 수 있게 빈 목록 반환
        return json({
          feed: feedKey,
          articles: [],
          error: `feed "${feedKey}" 의 RSS URL이 설정되지 않았습니다. ` +
            `feeds.ts 또는 환경변수(NEWS_TOP_RSS 등)를 채워주세요.`,
        });
      }
      const res = await fetch(feed.url, {
        headers: { 'User-Agent': 'Mozilla/5.0 (news-crawl proxy)' },
      });
      if (!res.ok) {
        return json(
          { feed: feedKey, articles: [], error: `소스 응답 ${res.status}` },
          502,
        );
      }
      const xml = await res.text();
      let articles = parseRss(xml, feed.label);
      if (query) {
        const q = query.toLowerCase();
        articles = articles.filter(
          (a) =>
            a.title.toLowerCase().includes(q) ||
            a.summary.toLowerCase().includes(q),
        );
      }
      return json({ feed: feedKey, articles });
    }

    // kind === 'scrape' — 전용 파서 구현 자리
    return json({
      feed: feedKey,
      articles: [],
      error: `scrape 타입 피드(${feedKey})는 아직 구현되지 않았습니다.`,
    });
  } catch (e) {
    console.error('news-crawl error:', e);
    return json({ articles: [], error: String(e) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
