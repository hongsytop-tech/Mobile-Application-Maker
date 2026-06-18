// 뉴스 피드 레지스트리.
//
// TODO(news): 실제 사용할 소스가 확정되면 여기 URL만 채우면 된다.
// RSS 기반 소스(연합뉴스/한겨레/구글뉴스 등)는 url 만 넣으면 동작하고,
// HTML 스크래핑이 필요한 소스(네이버 검색 등)는 type='scrape' 로 두고
// index.ts 에 전용 파서를 추가하는 식으로 확장한다.

export type FeedKind = 'rss' | 'scrape';

export interface FeedDef {
  key: string;
  label: string;
  kind: FeedKind;
  url?: string; // rss 일 때 사용
}

export const FEEDS: Record<string, FeedDef> = {
  // 예시 자리 — 소스 확정 전까지 url 비워둠.
  // 채우는 순간 클라이언트 수정 없이 바로 동작한다.
  top: {
    key: 'top',
    label: '주요뉴스',
    kind: 'rss',
    url: Deno.env.get('NEWS_TOP_RSS') ?? '',
  },
};

export function resolveFeed(key: string): FeedDef | null {
  return FEEDS[key] ?? null;
}
