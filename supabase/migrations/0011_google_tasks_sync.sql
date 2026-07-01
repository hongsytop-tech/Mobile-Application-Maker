-- Google Tasks 자동 동기화용 토큰 저장소.
-- refresh_token 으로 백엔드(cron)가 주기적으로 Google Tasks 를 읽어
-- user_data.memos 에 새 항목을 메모로 추가한다.
-- Edge Function 이 service_role 로 접근하므로 RLS 는 본인 존재확인(select)·해제(delete)만 허용.

create table if not exists public.google_tasks_sync (
  user_id uuid primary key references auth.users(id) on delete cascade,
  refresh_token text not null,
  -- 이미 메모로 가져온 Google Task id 목록 (중복 방지)
  imported_task_ids jsonb not null default '[]'::jsonb,
  last_synced_at timestamptz,
  last_error text,
  linked_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.google_tasks_sync enable row level security;

-- 본인 연동 상태 조회 (refresh_token 컬럼도 정책상 노출되지만 JWT 본인 행만 보임)
drop policy if exists google_tasks_sync_self_select on public.google_tasks_sync;
create policy google_tasks_sync_self_select on public.google_tasks_sync
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists google_tasks_sync_self_delete on public.google_tasks_sync;
create policy google_tasks_sync_self_delete on public.google_tasks_sync
  for delete to authenticated using (auth.uid() = user_id);
