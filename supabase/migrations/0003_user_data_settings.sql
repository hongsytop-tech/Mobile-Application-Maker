-- 단일 값 설정 (문구 순차 알림 등) 동기화용 컬럼.
-- 키-값 형식 ({"quote_rotation_settings_v1": "{...json...}"}).

alter table public.user_data
  add column if not exists settings jsonb not null default '{}'::jsonb;
