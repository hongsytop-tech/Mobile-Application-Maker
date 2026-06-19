-- 메모장 데이터용 컬럼 추가
alter table public.user_data
  add column if not exists memos jsonb not null default '[]'::jsonb;
