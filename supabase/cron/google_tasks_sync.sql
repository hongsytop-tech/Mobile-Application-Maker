-- Google Tasks 자동 동기화 cron (15분마다 google-tasks:sync_all 호출).
-- Supabase SQL Editor 에서 아래 값을 바꿔 실행하세요.
--   {PROJECT_REF}      : Supabase 프로젝트 ref (예: abcd1234)
--   {SCHEDULER_SECRET} : web-push 와 동일한 스케줄러 시크릿
--
-- pg_cron, pg_net 확장이 필요합니다 (web-push cron 이 이미 있으면 활성화돼 있음).

-- (필요 시) 확장 활성화
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 기존 동일 job 이 있으면 제거 후 재등록
select cron.unschedule('google_tasks_sync')
where exists (select 1 from cron.job where jobname = 'google_tasks_sync');

select cron.schedule(
  'google_tasks_sync',
  '*/15 * * * *',              -- 15분마다
  $$
  select net.http_post(
    url := 'https://{PROJECT_REF}.supabase.co/functions/v1/google-tasks',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer {SCHEDULER_SECRET}'
    ),
    body := jsonb_build_object('action', 'sync_all')
  );
  $$
);

-- 확인:
--   select jobname, schedule, active from cron.job;
--   select * from cron.job_run_details order by start_time desc limit 10;
