-- 예약된 푸시 알림 큐 (문구 순차 알림, 할일 알림 등)
-- pg_cron 이 1분마다 Edge Function 을 호출해 도래한 항목을 발송.

create table if not exists public.scheduled_pushes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,            -- 'quote_rotation' | 'todo_once' | 'todo_repeat'
  ref_id text,                   -- 외부 참조 (todo id, slot idx 등)
  title text not null,
  body text not null,
  url text,
  scheduled_at timestamptz not null,
  sent_at timestamptz,
  attempt_count int not null default 0,
  last_error text,
  created_at timestamptz not null default now()
);

create index if not exists scheduled_pushes_due_idx
  on public.scheduled_pushes (scheduled_at)
  where sent_at is null;

create index if not exists scheduled_pushes_user_kind_idx
  on public.scheduled_pushes (user_id, kind);

alter table public.scheduled_pushes enable row level security;

drop policy if exists scheduled_pushes_self on public.scheduled_pushes;
create policy scheduled_pushes_self on public.scheduled_pushes
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
