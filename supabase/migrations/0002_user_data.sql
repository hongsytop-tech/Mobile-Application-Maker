-- 사용자별 앱 데이터 (책장·문구·일기·할 일) 백업·동기화용
-- 각 컬럼은 SharedPreferences StringList를 그대로 옮긴 jsonb 배열.

create table if not exists public.user_data (
  user_id         uuid primary key references auth.users(id) on delete cascade,
  books           jsonb not null default '[]'::jsonb,
  quotes          jsonb not null default '[]'::jsonb,
  diaries         jsonb not null default '[]'::jsonb,
  todo_categories jsonb not null default '[]'::jsonb,
  todo_items      jsonb not null default '[]'::jsonb,
  updated_at      timestamptz not null default now()
);

alter table public.user_data enable row level security;

-- 본인만 접근
drop policy if exists "user_data own access" on public.user_data;
create policy "user_data own access" on public.user_data
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 회원가입 시 빈 행 자동 생성
create or replace function public.create_user_data_on_signup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_data (user_id) values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.create_user_data_on_signup();
