-- 운동 기록 데이터용 컬럼 추가
alter table public.user_data
  add column if not exists exercise_logs jsonb not null default '[]'::jsonb;
