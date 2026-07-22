-- 메모 폴더 데이터용 컬럼 추가
alter table public.user_data
  add column if not exists memo_folders jsonb not null default '[]'::jsonb;
