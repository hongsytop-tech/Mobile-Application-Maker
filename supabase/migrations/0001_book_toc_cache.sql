-- 책 메타데이터(목차·가격·링크) 캐시 테이블
-- ISBN을 키로 외부 API(알라딘/교보문고/NLK) 호출 결과를 저장하여
-- 봇 차단 영향 최소화 + 외부 호출 절감 + 응답 속도 향상.

create table if not exists public.book_toc_cache (
  isbn            text primary key,
  toc             jsonb       not null default '[]'::jsonb,
  toc_source      text,
  price_standard  integer,
  price_sales     integer,
  aladin_link     text,
  kyobo_link      text,
  cached_at       timestamptz not null default now(),
  expires_at      timestamptz not null default now() + interval '30 days'
);

create index if not exists book_toc_cache_expires_at_idx
  on public.book_toc_cache (expires_at);

-- RLS 활성화: service_role(Edge Function)만 접근, 일반 클라이언트 차단.
alter table public.book_toc_cache enable row level security;
-- (정책 없음 = anon/authenticated 접근 불가, service_role은 RLS 우회)
